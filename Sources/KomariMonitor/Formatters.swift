import Foundation

enum Fmt {
    static func pct(_ value: Double) -> String {
        value >= 10 ? String(format: "%.0f%%", value) : String(format: "%.1f%%", value)
    }

    static func bytes(_ value: Double) -> String {
        var v = max(0, value)
        let units = ["B", "K", "M", "G", "T", "P"]
        var idx = 0
        while v >= 1024, idx < units.count - 1 {
            v /= 1024
            idx += 1
        }
        if idx == 0 { return String(format: "%.0f%@", v, units[idx]) }
        if abs(v.rounded() - v) < 0.05 { return String(format: "%.0f%@", v.rounded(), units[idx]) }
        return v < 10 ? String(format: "%.1f%@", v, units[idx]) : String(format: "%.0f%@", v, units[idx])
    }

    static func rate(_ value: Double) -> String {
        "\(bytes(value))/s"
    }

    static func uptime(_ seconds: Double) -> String {
        let seconds = max(0, Int(seconds))
        let days = seconds / 86_400
        let hours = seconds % 86_400 / 3_600
        let minutes = seconds % 3_600 / 60
        if days > 0 { return "\(days)d\(hours)h" }
        if hours > 0 { return "\(hours)h\(minutes)m" }
        return "\(minutes)m"
    }

    static func age(_ date: Date) -> String {
        if date == .distantPast { return "-" }
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h"
    }

    static func expiry(_ date: Date?) -> String {
        guard let date else { return "-" }
        let days = Int(date.timeIntervalSinceNow / 86_400)
        if days < 0 { return "expired \(abs(days))d" }
        return "\(days)d"
    }
}

func number(_ value: Any?) -> Double {
    if let value = value as? Double { return value }
    if let value = value as? Int { return Double(value) }
    if let value = value as? Int64 { return Double(value) }
    if let value = value as? String { return Double(value) ?? 0 }
    return 0
}

func string(_ value: Any?) -> String {
    if let value = value as? String { return value }
    return ""
}

func parseDate(_ value: Any?) -> Date? {
    if let value = value as? Double {
        return Date(timeIntervalSince1970: value > 10_000_000_000 ? value / 1000 : value)
    }
    if let value = value as? Int {
        let doubleValue = Double(value)
        return Date(timeIntervalSince1970: doubleValue > 10_000_000_000 ? doubleValue / 1000 : doubleValue)
    }
    guard var text = value as? String, !text.isEmpty, !text.hasPrefix("0001-") else { return nil }
    if text.hasSuffix("Z") {
        text = String(text.dropLast()) + "+00:00"
    }
    return ISO8601DateFormatter().date(from: text)
}
