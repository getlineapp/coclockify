import SwiftUI
import XCTest
@testable import cocotrack

final class DateDecodingTests: XCTestCase {

    func testDecodesFractionalSecondTimestamps() throws {
        let json = #"{"id":"e1","timeInterval":{"start":"2026-07-23T08:15:30.123Z","end":"2026-07-23T09:15:30.123Z"}}"#
        let entry = try JSONDecoder.clockifyDecoder.decode(ClockifyTimeEntry.self, from: Data(json.utf8))
        XCTAssertEqual(entry.durationSeconds, 3600)
    }

    func testDecodesNonFractionalSecondTimestamps() throws {
        let json = #"{"id":"e1","timeInterval":{"start":"2026-07-23T08:15:30Z","end":"2026-07-23T08:16:00Z"}}"#
        let entry = try JSONDecoder.clockifyDecoder.decode(ClockifyTimeEntry.self, from: Data(json.utf8))
        XCTAssertEqual(entry.durationSeconds, 30)
    }

    func testRunningEntryHasNoDuration() throws {
        let json = #"{"id":"e1","timeInterval":{"start":"2026-07-23T08:15:30Z"}}"#
        let entry = try JSONDecoder.clockifyDecoder.decode(ClockifyTimeEntry.self, from: Data(json.utf8))
        XCTAssertNil(entry.timeInterval.end)
        XCTAssertNil(entry.durationSeconds)
    }

    func testMalformedTimestampFailsLoudlyRatherThanDefaulting() {
        let json = #"{"id":"e1","timeInterval":{"start":"not-a-date"}}"#
        XCTAssertThrowsError(try JSONDecoder.clockifyDecoder.decode(ClockifyTimeEntry.self, from: Data(json.utf8)))
    }

    /// An end before the start would otherwise produce a negative duration and a
    /// nonsensical day total.
    func testInvertedIntervalClampsToZeroRatherThanGoingNegative() throws {
        let json = #"{"id":"e1","timeInterval":{"start":"2026-07-23T09:00:00Z","end":"2026-07-23T08:00:00Z"}}"#
        let entry = try JSONDecoder.clockifyDecoder.decode(ClockifyTimeEntry.self, from: Data(json.utf8))
        XCTAssertEqual(entry.durationSeconds, 0)
    }
}

final class TimeFormattingTests: XCTestCase {

    /// `DateFormatter` rewrites a fixed "HH" pattern into a 12-hour one when the
    /// user turns off "24-Hour Time", unless the locale is pinned. Entry ranges
    /// silently rendered as "2:15 – 3:40" with no AM/PM before the fix.
    func testTimeRangeStaysTwentyFourHourRegardlessOfSystemPreference() throws {
        let json = #"{"id":"e1","timeInterval":{"start":"2026-07-23T14:15:00Z","end":"2026-07-23T15:40:00Z"}}"#
        let entry = try JSONDecoder.clockifyDecoder.decode(ClockifyTimeEntry.self, from: Data(json.utf8))

        let text = entry.timeRangeText
        XCTAssertFalse(text.uppercased().contains("AM"), "Got: \(text)")
        XCTAssertFalse(text.uppercased().contains("PM"), "Got: \(text)")
        // Two zero-padded HH:mm stamps around an en dash.
        XCTAssertNotNil(text.range(of: #"^\d{2}:\d{2} – \d{2}:\d{2}$"#, options: .regularExpression), "Got: \(text)")
    }

    func testRunningEntryRangeIsOpenEnded() throws {
        let json = #"{"id":"e1","timeInterval":{"start":"2026-07-23T14:15:00Z"}}"#
        let entry = try JSONDecoder.clockifyDecoder.decode(ClockifyTimeEntry.self, from: Data(json.utf8))
        XCTAssertTrue(entry.timeRangeText.hasSuffix("– ..."), "Got: \(entry.timeRangeText)")
    }

    func testDurationFormatting() {
        XCTAssertEqual(0.formattedDuration, "00:00:00")
        XCTAssertEqual(59.formattedDuration, "00:00:59")
        XCTAssertEqual(3600.formattedDuration, "01:00:00")
        XCTAssertEqual(3661.formattedDuration, "01:01:01")
        XCTAssertEqual((99 * 3600).formattedDuration, "99:00:00")
    }

    /// Day totals can exceed 100 hours once several long entries are grouped;
    /// the hour field must widen rather than wrap.
    func testDurationBeyondNinetyNineHoursDoesNotWrap() {
        XCTAssertEqual((123 * 3600 + 45 * 60 + 6).formattedDuration, "123:45:06")
    }
}

final class ColorParsingTests: XCTestCase {

    func testParsesLeadingHashHexColors() {
        XCTAssertNotNil(Color(hex: "#D27B4D"))
        XCTAssertNotNil(Color(hex: "d27b4d"))
    }

    func testRejectsWrongLengthValues() {
        XCTAssertNil(Color(hex: ""))
        XCTAssertNil(Color(hex: "#FFF"))
        XCTAssertNil(Color(hex: "#D27B4DFF"))
    }

    /// Clockify has no schema guarantee on the colour field; a junk value must
    /// fall back to the neutral swatch rather than crash or render as black.
    func testRejectsNonHexGarbage() {
        XCTAssertNil(Color(hex: "not a colour"))
    }
}

final class TimeEntryPayloadTests: XCTestCase {

    private func encoded(_ value: some Encodable) throws -> [String: Any] {
        let encoder = JSONEncoder.clockifyEncoder
        let data = try encoder.encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testUpdatePayloadCarriesAllProvidedFields() throws {
        let payload = ClockifyUpdateTimeEntryRequest(
            start: "2026-07-23T08:00:00.000Z",
            description: "standup",
            end: "2026-07-23T08:15:00.000Z",
            projectId: "p1"
        )
        let json = try encoded(payload)

        XCTAssertEqual(json["start"] as? String, "2026-07-23T08:00:00.000Z")
        XCTAssertEqual(json["description"] as? String, "standup")
        XCTAssertEqual(json["end"] as? String, "2026-07-23T08:15:00.000Z")
        XCTAssertEqual(json["projectId"] as? String, "p1")
    }

    /// Under Clockify's full-replace PUT semantics an omitted field is reset, so
    /// omitting nils is how "remove the project" and "keep this entry running"
    /// are expressed. Verified against the live API during the audit.
    func testNilFieldsAreOmittedFromUpdatePayload() throws {
        let payload = ClockifyUpdateTimeEntryRequest(
            start: "2026-07-23T08:00:00.000Z",
            description: "standup",
            end: nil,
            projectId: nil
        )
        let json = try encoded(payload)

        XCTAssertEqual(Set(json.keys), ["start", "description"])
    }

    private func entry(
        taskId: String?,
        billable: Bool?,
        tagIds: [String]?,
        projectId: String? = "p1",
        end: String? = "2026-07-23T09:00:00Z"
    ) throws -> ClockifyTimeEntry {
        var interval = #"{"start":"2026-07-23T08:00:00Z""#
        if let end { interval += #","end":"\#(end)""# }
        interval += "}"

        var fields = [#""id":"e1""#, #""description":"standup""#, #""timeInterval":\#(interval)"#]
        if let projectId { fields.append(#""projectId":"\#(projectId)""#) }
        if let taskId { fields.append(#""taskId":"\#(taskId)""#) }
        if let billable { fields.append(#""billable":\#(billable)"#) }
        if let tagIds { fields.append(#""tagIds":[\#(tagIds.map { "\"\($0)\"" }.joined(separator: ","))]"#) }

        return try JSONDecoder.clockifyDecoder.decode(
            ClockifyTimeEntry.self,
            from: Data("{\(fields.joined(separator: ","))}".utf8)
        )
    }

    /// The audit's headline data-loss bug: `PUT /time-entries/{id}` replaces the
    /// whole record, and the app only ever sent start/description/end/projectId —
    /// so renaming an entry wiped its tags and task assignment on the server.
    func testUpdatePreservesTagsAndTaskWhenOnlyTheDescriptionChanges() throws {
        let existing = try entry(taskId: "t1", billable: true, tagIds: ["tag1", "tag2"])

        let payload = ClockifyUpdateTimeEntryRequest(
            preserving: existing,
            start: existing.timeInterval.start,
            description: "renamed",
            end: existing.timeInterval.end,
            projectId: existing.projectId
        )
        let json = try encoded(payload)

        XCTAssertEqual(json["description"] as? String, "renamed")
        XCTAssertEqual(json["taskId"] as? String, "t1")
        XCTAssertEqual(json["billable"] as? Bool, true)
        XCTAssertEqual(json["tagIds"] as? [String], ["tag1", "tag2"])
        XCTAssertEqual(json["projectId"] as? String, "p1")
        XCTAssertNotNil(json["end"])
    }

    func testChangingTheProjectKeepsEverythingElseIntact() throws {
        let existing = try entry(taskId: "t1", billable: false, tagIds: ["tag1"])

        let payload = ClockifyUpdateTimeEntryRequest(
            preserving: existing,
            start: existing.timeInterval.start,
            description: existing.description ?? "",
            end: existing.timeInterval.end,
            projectId: "p2"
        )
        let json = try encoded(payload)

        XCTAssertEqual(json["projectId"] as? String, "p2")
        XCTAssertEqual(json["taskId"] as? String, "t1")
        XCTAssertEqual(json["billable"] as? Bool, false)
        XCTAssertEqual(json["tagIds"] as? [String], ["tag1"])
    }

    /// Clearing the project is expressed by omitting the field, and must not drag
    /// the other attributes down with it.
    func testClearingTheProjectOmitsOnlyTheProject() throws {
        let existing = try entry(taskId: "t1", billable: true, tagIds: ["tag1"])

        let payload = ClockifyUpdateTimeEntryRequest(
            preserving: existing,
            start: existing.timeInterval.start,
            description: existing.description ?? "",
            end: existing.timeInterval.end,
            projectId: nil
        )
        let json = try encoded(payload)

        XCTAssertNil(json["projectId"])
        XCTAssertEqual(json["tagIds"] as? [String], ["tag1"])
        XCTAssertEqual(json["taskId"] as? String, "t1")
    }

    /// A running entry has no end; the field must stay absent so the PUT does not
    /// close it, while its tags still survive.
    func testRunningEntryKeepsRunningAndKeepsItsTags() throws {
        let existing = try entry(taskId: nil, billable: true, tagIds: ["tag1"], end: nil)

        let payload = ClockifyUpdateTimeEntryRequest(
            preserving: existing,
            start: existing.timeInterval.start,
            description: "still going",
            end: nil,
            projectId: existing.projectId
        )
        let json = try encoded(payload)

        XCTAssertNil(json["end"])
        XCTAssertNil(json["taskId"])
        XCTAssertEqual(json["tagIds"] as? [String], ["tag1"])
    }

    func testEntryWithoutTagsOrTaskEncodesWithoutThoseKeys() throws {
        let existing = try entry(taskId: nil, billable: nil, tagIds: nil)

        let payload = ClockifyUpdateTimeEntryRequest(
            preserving: existing,
            start: existing.timeInterval.start,
            description: "plain",
            end: existing.timeInterval.end,
            projectId: existing.projectId
        )
        let json = try encoded(payload)

        XCTAssertEqual(Set(json.keys), ["start", "description", "end", "projectId"])
    }

    func testCreatePayloadOmitsAbsentProject() throws {
        let payload = ClockifyCreateTimeEntryRequest(
            start: "2026-07-23T08:00:00.000Z",
            description: "standup",
            projectId: nil
        )
        let json = try encoded(payload)

        XCTAssertEqual(Set(json.keys), ["start", "description"])
    }

    func testStopPayloadCarriesOnlyEnd() throws {
        let json = try encoded(ClockifyStopTimeEntryRequest(end: "2026-07-23T09:00:00.000Z"))
        XCTAssertEqual(Set(json.keys), ["end"])
    }

    /// Descriptions are user text and routinely contain slashes, emoji and
    /// non-ASCII; the encoder must not mangle them.
    func testUnicodeAndSlashesSurviveEncoding() throws {
        let payload = ClockifyCreateTimeEntryRequest(
            start: "2026-07-23T08:00:00.000Z",
            description: "klient/wsparcie — ćwiczenia 🚀",
            projectId: nil
        )
        let json = try encoded(payload)
        XCTAssertEqual(json["description"] as? String, "klient/wsparcie — ćwiczenia 🚀")
    }

    func testISO8601RoundTripUsesUTCWithFractionalSeconds() {
        let date = Date(timeIntervalSince1970: 1_753_257_600)
        let string = date.clockifyISO8601String
        XCTAssertTrue(string.hasSuffix("Z"), "Got: \(string)")
        XCTAssertNotNil(
            string.range(of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$"#, options: .regularExpression),
            "Got: \(string)"
        )
    }
}
