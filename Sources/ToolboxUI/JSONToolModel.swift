import Combine
import Foundation
import ToolboxCore

enum JSONMode: String, CaseIterable, Identifiable, Sendable {
    case format = "格式化", compress = "压缩", validate = "校验", compare = "对比"
    var id: String { rawValue }
}

@MainActor
final class JSONToolModel: ObservableObject {
    @Published var mode: JSONMode = .format { didSet { scheduleRecompute(delay: 0) } }
    @Published var leftText = "" { didSet { scheduleRecompute() } }
    @Published var rightText = "" { didSet { scheduleRecompute() } }
    @Published private(set) var outputText = ""
    @Published private(set) var message = "输入 JSON 后开始处理"
    @Published private(set) var isError = false
    @Published private(set) var isProcessing = false
    @Published private(set) var leftError: JSONParseError?
    @Published private(set) var rightError: JSONParseError?
    @Published private(set) var differences: [JSONDifference] = []
    private var generation = 0
    private var pending: DispatchWorkItem?
    private let worker = DispatchQueue(label: "com.nstoolbox.json", qos: .userInitiated)

    deinit { pending?.cancel() }

    func clear() {
        leftText = ""
        rightText = ""
        scheduleRecompute(delay: 0)
    }

    func formatBoth() {
        do {
            let left = try JSONParser.parse(leftText)
            let right = try JSONParser.parse(rightText)
            leftText = JSONWriter.write(left.value, pretty: true)
            rightText = JSONWriter.write(right.value, pretty: true)
        } catch {
            // Re-evaluate both sides to display the precise error; keep both inputs intact.
            scheduleRecompute(delay: 0)
        }
    }

    private func scheduleRecompute(delay: TimeInterval = 0.25) {
        generation += 1
        pending?.cancel()
        differences = []
        outputText = ""
        leftError = nil
        rightError = nil
        isError = false
        let left = leftText, right = rightText, selectedMode = mode, request = generation
        if left.isEmpty && (selectedMode != .compare || right.isEmpty) {
            isProcessing = false
            message = "输入 JSON 后开始处理"
            return
        }
        isProcessing = true
        message = "正在处理…"
        let work = DispatchWorkItem { [weak self] in
            let result = Self.calculate(mode: selectedMode, left: left, right: right)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == request else { return }
                self.outputText = result.output
                self.message = result.message
                self.isError = result.leftError != nil || result.rightError != nil
                self.leftError = result.leftError
                self.rightError = result.rightError
                self.differences = result.differences
                self.isProcessing = false
            }
        }
        pending = work
        worker.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private struct Evaluation: Sendable {
        var output = ""
        var message = ""
        var leftError: JSONParseError?
        var rightError: JSONParseError?
        var differences: [JSONDifference] = []
    }

    nonisolated private static func calculate(mode: JSONMode, left: String, right: String) -> Evaluation {
        var result = Evaluation()
        var lhs: JSONDocument?, rhs: JSONDocument?
        do { lhs = try JSONParser.parse(left) }
        catch let error as JSONParseError { result.leftError = error }
        catch { result.message = error.localizedDescription }
        if mode == .compare {
            do { rhs = try JSONParser.parse(right) }
            catch let error as JSONParseError { result.rightError = error }
            catch { result.message = error.localizedDescription }
        }
        let errors = [result.leftError.map { "左侧：" + $0.localizedDescription },
                      result.rightError.map { "右侧：" + $0.localizedDescription }].compactMap { $0 }
        if !errors.isEmpty { result.message = errors.joined(separator: "；"); return result }
        guard let lhs else { return result }
        switch mode {
        case .format: result.output = JSONWriter.write(lhs.value, pretty: true); result.message = "JSON 有效"
        case .compress: result.output = JSONWriter.write(lhs.value, pretty: false); result.message = "JSON 有效"
        case .validate: result.message = "JSON 有效"
        case .compare:
            guard let rhs else { return result }
            result.differences = JSONDiff.compare(lhs, rhs)
            result.message = result.differences.isEmpty ? "两侧 JSON 相同" : "发现 \(result.differences.count) 处差异"
        }
        return result
    }
}
