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

    /// Pins the wire format rather than endorsing it. Swift's synthesised
    /// `Encodable` *omits* nil optionals instead of sending JSON null, so
    /// "clear the project" and "clear the end time" are sent as absent fields.
    /// Whether Clockify treats an absent field as "leave unchanged" or "reset"
    /// is unverified against the live API — see AUDIT_REPORT.md (P1-3). This test
    /// exists so that any change to that behaviour is a deliberate decision and
    /// not an accident.
    func testNilFieldsAreOmittedFromUpdatePayload() throws {
        let payload = ClockifyUpdateTimeEntryRequest(
            start: "2026-07-23T08:00:00.000Z",
            description: "standup",
            end: nil,
            projectId: nil
        )
        let json = try encoded(payload)

        XCTAssertEqual(Set(json.keys), ["start", "description"])
        XCTAssertNil(json["end"])
        XCTAssertNil(json["projectId"])
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
