import Combine
import Foundation
import ToolboxCore

enum TimestampMode: String, CaseIterable, Identifiable {
    case convert = "转换", batch = "批量", difference = "时间差"
    var id: String { rawValue }
}

@MainActor
final class TimestampToolModel: ObservableObject {
    @Published var mode: TimestampMode = .convert
    @Published var unit: TimestampUnit = .seconds { didSet { settingsChanged() } }
    @Published var format: TimestampDateFormat = .standard { didSet { settingsChanged() } }
    @Published var timeZoneID = TimeZone.current.identifier { didSet { settingsChanged() } }
    @Published var epochInput = "" { didSet { recompute() } }
    @Published var dateInput = "" { didSet { recompute() } }
    @Published private(set) var dateOutput = ""
    @Published private(set) var epochOutput = ""
    @Published private(set) var epochError = ""
    @Published private(set) var dateError = ""
    @Published var now = Date()
    @Published var isClockPaused = false
    @Published var direction: TimestampDirection = .toDate { didSet { invalidateBatch() } }
    @Published var batchInput = "" { didSet { invalidateBatch() } }
    @Published private(set) var batchOutput = ""
    @Published private(set) var batchMessage = "每行一个值，点击转换；空行保留"
    @Published private(set) var batchHasError = false
    @Published private(set) var isProcessing = false
    @Published var startInput = "" { didSet { recomputeDifference() } }
    @Published var endInput = "" { didSet { recomputeDifference() } }
    @Published private(set) var differenceOutput = ""
    @Published private(set) var differenceError = ""
    private var batchRevision = 0

    var currentSeconds: String { String(Int64(now.timeIntervalSince1970.rounded(.down))) }
    var currentMilliseconds: String { String(Int64((now.timeIntervalSince1970 * 1000).rounded(.down))) }
    var isError: Bool {
        switch mode {
        case .convert: return !epochError.isEmpty || !dateError.isEmpty
        case .batch: return batchHasError
        case .difference: return !differenceError.isEmpty
        }
    }
    var message: String {
        switch mode {
        case .convert:
            if !epochError.isEmpty { return epochError }
            if !dateError.isEmpty { return dateError }
            return epochInput.isEmpty && dateInput.isEmpty ? "输入后实时转换 · 时间单位需手动选择" : "转换完成 · \(timeZoneID)"
        case .batch: return isProcessing ? "正在转换…" : batchMessage
        case .difference: return differenceError.isEmpty ? "结束 − 开始 · 1 天 = 24 小时，可返回负值" : differenceError
        }
    }

    func fillCurrent() {
        epochInput = unit == .seconds ? currentSeconds : currentMilliseconds
        if let zone = try? TimestampUtility.timeZone(timeZoneID) {
            dateInput = (try? TimestampUtility.dateString(from: epochInput, unit: unit, timeZone: zone, format: format)) ?? ""
        }
    }

    private func settingsChanged() {
        recompute()
        recomputeDifference()
        invalidateBatch()
    }

    private func recompute() {
        dateOutput = ""; epochOutput = ""; epochError = ""; dateError = ""
        if !epochInput.isEmpty {
            do {
                dateOutput = try TimestampUtility.dateString(from: epochInput, unit: unit,
                    timeZone: TimestampUtility.timeZone(timeZoneID), format: format)
            } catch { epochError = error.localizedDescription }
        }
        if !dateInput.isEmpty {
            do {
                epochOutput = try TimestampUtility.timestamp(from: dateInput, unit: unit,
                    timeZone: TimestampUtility.timeZone(timeZoneID))
            } catch { dateError = error.localizedDescription }
        }
    }

    private func invalidateBatch() {
        batchRevision += 1
        batchOutput = ""
        batchHasError = false
        batchMessage = "每行一个值，点击转换；空行保留"
    }

    func convertBatch() {
        guard !isProcessing else { return }
        invalidateBatch()
        guard !batchInput.isEmpty else { return }
        let zone: TimeZone
        do { zone = try TimestampUtility.timeZone(timeZoneID) }
        catch { batchHasError = true; batchMessage = error.localizedDescription; return }
        let source = batchInput, direction = direction, unit = unit, format = format, revision = batchRevision
        isProcessing = true
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result { try TimestampUtility.batch(source, direction: direction, unit: unit, timeZone: zone, format: format) }
            }.value
            isProcessing = false
            guard revision == batchRevision else { return }
            switch result {
            case .success(let value):
                batchOutput = value.output
                batchHasError = value.errorCount > 0
                batchMessage = "成功 \(value.successCount) 行 · 错误 \(value.errorCount) 行"
            case .failure(let error):
                batchHasError = true
                batchMessage = error.localizedDescription
            }
        }
    }

    private func recomputeDifference() {
        differenceOutput = ""; differenceError = ""
        guard !startInput.isEmpty && !endInput.isEmpty else { return }
        do {
            let milliseconds = try TimestampUtility.difference(start: startInput, end: endInput,
                timeZone: TimestampUtility.timeZone(timeZoneID))
            let magnitude = milliseconds.magnitude
            let seconds = "\(milliseconds < 0 ? "-" : "")\(magnitude / 1000).\(String(format: "%03llu", magnitude % 1000))"
            differenceOutput = "\(TimestampUtility.durationDescription(milliseconds: milliseconds))\n\n总毫秒：\(milliseconds)\n总秒数：\(seconds)"
        } catch { differenceError = error.localizedDescription }
    }
}
