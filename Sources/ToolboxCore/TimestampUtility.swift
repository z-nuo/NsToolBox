import Foundation

public enum TimestampUnit: String, CaseIterable, Identifiable, Sendable {
    case seconds = "秒", milliseconds = "毫秒"
    public var id: String { rawValue }
}

public enum TimestampDateFormat: String, CaseIterable, Identifiable, Sendable {
    case standard = "标准日期", iso8601 = "ISO 8601"
    public var id: String { rawValue }
}

public enum TimestampUtility {
    // Allow a one-day UTC margin so local dates at the 1900/9999 boundaries survive zone offsets.
    private static let range: ClosedRange<Int64> = -2_209_075_200_000...253_402_387_199_999

    public static func timeZone(_ identifier: String) throws -> TimeZone {
        guard !identifier.isEmpty, let zone = TimeZone(identifier: identifier) else { throw DeveloperUtilityError.invalidTimeZone }
        return zone
    }

    public static func milliseconds(from source: String, unit: TimestampUnit) throws -> Int64 {
        guard let value = Int64(source), source == String(value) || source == "+" + String(value) else {
            throw DeveloperUtilityError.invalidTimestamp
        }
        let (scaled, overflow) = value.multipliedReportingOverflow(by: unit == .seconds ? 1000 : 1)
        guard !overflow, range.contains(scaled) else { throw DeveloperUtilityError.invalidTimestamp }
        return scaled
    }

    private static func parts(_ milliseconds: Int64) -> (seconds: Int64, fraction: Int64) {
        let fraction = (milliseconds % 1000 + 1000) % 1000
        return ((milliseconds - fraction) / 1000, fraction)
    }

    public static func dateString(from source: String, unit: TimestampUnit, timeZone: TimeZone,
                                  format: TimestampDateFormat = .standard) throws -> String {
        let value = try milliseconds(from: source, unit: unit)
        let split = parts(value)
        let date = Date(timeIntervalSince1970: Double(split.seconds))
        let formatter = makeFormatter(timeZone: timeZone)
        let base = formatter.string(from: date)
        guard base.count == 19, let year = Int(base.prefix(4)), (1900...9999).contains(year) else {
            throw DeveloperUtilityError.invalidTimestamp
        }
        let fraction = unit == .milliseconds ? String(format: ".%03lld", split.fraction) : ""
        if format == .standard { return base + fraction }
        let offset = timeZone.secondsFromGMT(for: date)
        // Historic zones can have second-level offsets, which RFC 3339 cannot represent.
        guard offset % 60 == 0 else { throw TimestampError.unsupportedOffset }
        let suffix = offset == 0 ? "Z" : String(format: "%@%02d:%02d", offset < 0 ? "-" : "+", abs(offset) / 3600, abs(offset) % 3600 / 60)
        return base.replacingOccurrences(of: " ", with: "T") + fraction + suffix
    }

    public static func timestamp(from source: String, unit: TimestampUnit, timeZone: TimeZone) throws -> String {
        let value = try parseDate(source, timeZone: timeZone)
        return String(unit == .milliseconds ? value : parts(value).seconds)
    }

    public static func parseDate(_ source: String, timeZone: TimeZone) throws -> Int64 {
        // Local yyyy-MM-dd HH:mm:ss[.SSS], or RFC 3339 with an explicit offset.
        let pattern = #"^([0-9]{4}-[0-9]{2}-[0-9]{2})[ T]([0-9]{2}:[0-9]{2}:[0-9]{2})(?:\.([0-9]{1,3}))?(Z|[+-][0-9]{2}:[0-9]{2})?$"#
        let regex = try NSRegularExpression(pattern: pattern)
        let ns = source as NSString
        guard let match = regex.firstMatch(in: source, range: NSRange(location: 0, length: ns.length)), match.range.length == ns.length else {
            throw DeveloperUtilityError.invalidDate
        }
        func group(_ index: Int) -> String {
            match.range(at: index).location == NSNotFound ? "" : ns.substring(with: match.range(at: index))
        }
        let base = group(1) + " " + group(2)
        let suffix = group(4)
        guard let year = Int(base.prefix(4)), (1900...9999).contains(year), !source.contains("T") || !suffix.isEmpty else {
            throw DeveloperUtilityError.invalidDate
        }
        var zone = timeZone
        if !suffix.isEmpty {
            if suffix == "Z" { zone = TimeZone(secondsFromGMT: 0)! }
            else {
                let hours = Int(suffix.dropFirst().prefix(2))!
                let minutes = Int(suffix.suffix(2))!
                guard hours <= 14, minutes < 60, hours < 14 || minutes == 0 else { throw DeveloperUtilityError.invalidDate }
                zone = TimeZone(secondsFromGMT: (suffix.first == "-" ? -1 : 1) * (hours * 3600 + minutes * 60))!
            }
        }
        let formatter = makeFormatter(timeZone: zone)
        guard let date = formatter.date(from: base), formatter.string(from: date) == base else { throw DeveloperUtilityError.invalidDate }
        if suffix.isEmpty {
            let chosenOffset = zone.secondsFromGMT(for: date)
            for nearby in [date.addingTimeInterval(-86_400), date.addingTimeInterval(86_400)] {
                let otherOffset = zone.secondsFromGMT(for: nearby)
                guard otherOffset != chosenOffset else { continue }
                let alternative = date.addingTimeInterval(TimeInterval(chosenOffset - otherOffset))
                if formatter.string(from: alternative) == base { throw DeveloperUtilityError.ambiguousDate }
            }
        }
        let fraction = group(3)
        let millis = fraction.isEmpty ? 0 : Int64(fraction.padding(toLength: 3, withPad: "0", startingAt: 0))!
        let value = Int64(date.timeIntervalSince1970.rounded()) * 1000 + millis
        guard range.contains(value) else { throw DeveloperUtilityError.invalidDate }
        return value
    }

    private static func makeFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.isLenient = false
        return formatter
    }
}

public enum TimestampError: Error, LocalizedError {
    case batchLimit, unsupportedOffset
    public var errorDescription: String? {
        switch self {
        case .batchLimit: return "批量输入最多 1000 行、128 KB"
        case .unsupportedOffset: return "该历史时区含秒级偏移，请改用标准日期或 UTC"
        }
    }
}

public enum TimestampDirection: String, CaseIterable, Identifiable, Sendable {
    case toDate = "时间戳 → 日期", toTimestamp = "日期 → 时间戳"
    public var id: String { rawValue }
}

public struct TimestampBatchResult: Sendable {
    public let output: String
    public let successCount: Int
    public let errorCount: Int
}

extension TimestampUtility {
    public static func batch(_ source: String, direction: TimestampDirection, unit: TimestampUnit,
                             timeZone: TimeZone, format: TimestampDateFormat = .standard) throws -> TimestampBatchResult {
        guard source.utf8.count <= 131_072 else { throw TimestampError.batchLimit }
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        guard lines.count <= 1000 else { throw TimestampError.batchLimit }
        var successes = 0, errors = 0
        let output = lines.enumerated().map { index, line -> String in
            let input = line.trimmingCharacters(in: .whitespaces)
            guard !input.isEmpty else { return "" }
            do {
                let value = try direction == .toDate
                    ? dateString(from: input, unit: unit, timeZone: timeZone, format: format)
                    : timestamp(from: input, unit: unit, timeZone: timeZone)
                successes += 1
                return value
            } catch {
                errors += 1
                return "第 \(index + 1) 行错误：\(error.localizedDescription)"
            }
        }
        return TimestampBatchResult(output: output.joined(separator: "\n"), successCount: successes, errorCount: errors)
    }

    public static func difference(start: String, end: String, timeZone: TimeZone) throws -> Int64 {
        try parseDate(end, timeZone: timeZone) - parseDate(start, timeZone: timeZone)
    }

    public static func durationDescription(milliseconds: Int64) -> String {
        let magnitude = milliseconds.magnitude
        return "\(milliseconds < 0 ? "−" : "")\(magnitude / 86_400_000) 天 \(magnitude / 3_600_000 % 24) 小时 \(magnitude / 60_000 % 60) 分 \(magnitude / 1000 % 60) 秒 \(magnitude % 1000) 毫秒"
    }
}
