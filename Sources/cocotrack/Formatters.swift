import Foundation
import SwiftUI

extension Date {
    var clockifyISO8601String: String {
        ClockifyDateFormatters.withFractional.string(from: self)
    }

    var shortDateTime: String {
        formatted(date: .numeric, time: .shortened)
    }
}

enum ClockifyDateFormatters {
    nonisolated(unsafe) static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    nonisolated(unsafe) static let withoutFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
}

extension JSONDecoder {
    static let clockifyDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = ClockifyDateFormatters.withFractional.date(from: value) {
                return date
            }

            if let date = ClockifyDateFormatters.withoutFractional.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(value)")
        }
        return decoder
    }()
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 6 else { return nil }
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

extension JSONEncoder {
    static let clockifyEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }()
}

// MARK: - Duration formatting

extension Int {
    var formattedDuration: String {
        let h = self / 3600
        let m = (self % 3600) / 60
        let s = self % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

// MARK: - Time entry helpers

extension ClockifyTimeEntry {
    var durationSeconds: Int? {
        guard let end = timeInterval.end else { return nil }
        return max(0, Int(end.timeIntervalSince(timeInterval.start)))
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        // A fixed `dateFormat` without a fixed locale is not stable: when the
        // user turns off "24-Hour Time", CFDateFormatter rewrites "HH" into a
        // 12-hour pattern, so entry ranges silently render as e.g. "2:15 – 3:40"
        // with no AM/PM. Pinning en_US_POSIX makes "HH:mm" mean what it says.
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    var timeRangeText: String {
        let start = Self.timeFormatter.string(from: timeInterval.start)
        if let end = timeInterval.end {
            return "\(start) – \(Self.timeFormatter.string(from: end))"
        }
        return "\(start) – ..."
    }
}
