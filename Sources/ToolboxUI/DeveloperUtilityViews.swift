import Combine
import Foundation
import SwiftUI
import ToolboxCore

@MainActor
final class TimestampToolModel: ObservableObject {
    @Published var unit: TimestampUnit = .seconds { didSet { recompute() } }
    @Published var timeZoneID = TimeZone.current.identifier { didSet { recompute() } }
    @Published var epochInput = "" { didSet { recompute() } }
    @Published var dateInput = "" { didSet { recompute() } }
    @Published private(set) var dateOutput = ""
    @Published private(set) var epochOutput = ""
    @Published private(set) var message = "选择时间单位和时区后输入时间戳或日期"
    @Published private(set) var isError = false

    private func recompute() {
        dateOutput = ""
        epochOutput = ""
        isError = false
        guard !epochInput.isEmpty || !dateInput.isEmpty else {
            message = "选择时间单位和时区后输入时间戳或日期"
            return
        }
        do {
            let zone = try TimestampUtility.timeZone(timeZoneID)
            if !epochInput.isEmpty { dateOutput = try TimestampUtility.dateString(from: epochInput, unit: unit, timeZone: zone) }
            if !dateInput.isEmpty { epochOutput = try TimestampUtility.timestamp(from: dateInput, unit: unit, timeZone: zone) }
            message = "转换完成 · \(zone.identifier)"
        } catch {
            dateOutput = ""
            epochOutput = ""
            isError = true
            message = error.localizedDescription
        }
    }
}

struct TimestampToolView: View {
    @ObservedObject var model: TimestampToolModel

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceToolbar {
                Picker("时间戳单位", selection: $model.unit) {
                    ForEach(TimestampUnit.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(width: 150)
                Text("时区")
                TextField("例如 Asia/Shanghai", text: $model.timeZoneID)
                    .textFieldStyle(.roundedBorder).frame(width: 180)
                    .accessibilityIdentifier("timestamp-timezone")
                Spacer()
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("时间戳 → 日期").font(.headline)
                    TextField("输入整数时间戳（\(model.unit.rawValue)）", text: $model.epochInput)
                        .accessibilityIdentifier("timestamp-epoch-input")
                    outputRow("日期（\(model.timeZoneID)）", model.dateOutput)
                    Divider()
                    Text("日期 → 时间戳").font(.headline)
                    TextField("yyyy-MM-dd HH:mm:ss", text: $model.dateInput)
                        .accessibilityIdentifier("timestamp-date-input")
                    outputRow("时间戳（\(model.unit.rawValue)）", model.epochOutput)
                    Text("日期精确到秒；毫秒时间戳转日期时仅显示到秒。时间单位不会自动猜测；夏令时切换造成的无效或重复本地时间会拒绝转换。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(20)
            }
            Divider()
            WorkspaceStatus(message: model.message, isError: model.isError, counts: "时区 \(model.timeZoneID)")
        }.background(WorkspaceStyle.background)
    }

    private func outputRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary).frame(width: 180, alignment: .leading)
            Text(value.isEmpty ? "—" : value).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            Spacer()
            CopyButton(text: value).font(.system(size: 12)).controlSize(.small)
        }
    }
}

@MainActor
final class UUIDToolModel: ObservableObject {
    @Published var countInput = "1"
    @Published private(set) var output = ""
    @Published private(set) var message = "输入数量并生成 UUID v4"
    @Published private(set) var isError = false

    func generate() {
        output = ""
        isError = false
        do {
            guard let count = Int(countInput), countInput == String(count) else { throw DeveloperUtilityError.invalidCount }
            output = try UUIDUtility.generate(count: count).joined(separator: "\n")
            message = "已生成 \(count) 个 UUID v4"
        } catch {
            isError = true
            message = error.localizedDescription
        }
    }
}

struct UUIDToolView: View {
    @ObservedObject var model: UUIDToolModel

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceToolbar {
                Text("数量")
                TextField("1–1000", text: $model.countInput).frame(width: 80)
                Button("生成 UUID v4", action: model.generate)
                Spacer()
            }
            Divider()
            EditorPane(title: "UUID v4 结果", text: .constant(model.output), editable: false, syntax: false)
            Divider()
            WorkspaceStatus(message: model.message, isError: model.isError, counts: "最多 1000 个")
        }.background(WorkspaceStyle.background)
    }
}

@MainActor
final class HashToolModel: ObservableObject {
    static let maximumBytes = 2 * 1024 * 1024
    @Published var input = "" { didSet { recompute() } }
    @Published var algorithm: TextHashAlgorithm = .sha256 { didSet { recompute() } }
    @Published private(set) var output = ""
    @Published private(set) var isError = false
    var message: String {
        if isError { return "输入文本超过 2 MB（UTF-8）上限" }
        return input.isEmpty ? "输入 UTF-8 文本后计算摘要" : "已计算 \(algorithm.rawValue) 摘要"
    }

    private func recompute() {
        isError = input.utf8.count > Self.maximumBytes
        output = input.isEmpty || isError ? "" : TextHashUtility.digest(input, algorithm: algorithm)
    }
}

struct HashToolView: View {
    @ObservedObject var model: HashToolModel

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceToolbar {
                Picker("算法", selection: $model.algorithm) {
                    ForEach(TextHashAlgorithm.allCases) { Text($0.rawValue).tag($0) }
                }.frame(width: 160)
                Spacer()
                Text("文本摘要 · UTF-8").foregroundStyle(.secondary)
            }
            Divider()
            HSplitView {
                EditorPane(title: "输入文本", text: $model.input, syntax: false)
                EditorPane(title: "\(model.algorithm.rawValue) 摘要", text: .constant(model.output), editable: false, syntax: false)
            }
            Divider()
            WorkspaceStatus(message: model.message, isError: model.isError,
                            counts: "输入 \(model.input.utf8.count) 字节 · 摘要 \(model.output.count) 字符")
        }.background(WorkspaceStyle.background)
    }
}
