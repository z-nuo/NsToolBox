import SwiftUI
import ToolboxCore

struct TimestampToolView: View {
    @ObservedObject var model: TimestampToolModel

    var body: some View {
        VStack(spacing: 0) {
            clockBar
            Divider()
            WorkspaceToolbar {
                Picker("时间戳模式", selection: $model.mode) {
                    ForEach(TimestampMode.allCases) { Text($0.rawValue).tag($0) }
                }.labelsHidden().pickerStyle(.segmented).tint(WorkspaceStyle.accent).frame(width: 230)
                Spacer()
                if model.mode != .difference {
                    Picker("时间单位", selection: $model.unit) {
                        ForEach(TimestampUnit.allCases) { Text($0.rawValue).tag($0) }
                    }.labelsHidden().pickerStyle(.segmented).tint(WorkspaceStyle.accent).frame(width: 120)
                    Picker("日期输出", selection: $model.format) {
                        ForEach(TimestampDateFormat.allCases) { Text($0.rawValue).tag($0) }
                    }.labelsHidden().frame(width: 160)
                }
            }
            WorkspaceToolbar {
                Menu("快捷时区") {
                    Button("本地时区") { model.timeZoneID = TimeZone.current.identifier }
                    Button("UTC") { model.timeZoneID = "UTC" }
                    Button("北京时间") { model.timeZoneID = "Asia/Shanghai" }
                    Button("纽约") { model.timeZoneID = "America/New_York" }
                    Button("东京") { model.timeZoneID = "Asia/Tokyo" }
                }.frame(width: 94)
                TextField("例如 Asia/Shanghai", text: $model.timeZoneID)
                    .textFieldStyle(.roundedBorder).frame(width: 185)
                    .accessibilityIdentifier("timestamp-timezone")
                Spacer()
                if model.mode == .convert {
                    Button("填入当前时间", action: model.fillCurrent)
                } else if model.mode == .batch {
                    Picker("批量方向", selection: $model.direction) {
                        ForEach(TimestampDirection.allCases) { Text($0.rawValue).tag($0) }
                    }.labelsHidden().frame(width: 168)
                    Button("转换", action: model.convertBatch).disabled(model.isProcessing || model.batchInput.isEmpty)
                } else {
                    Text("日期输入支持 ISO 8601").foregroundStyle(.secondary)
                }
            }
            Divider()
            switch model.mode {
            case .convert: conversionPanes
            case .batch:
                HSplitView {
                    EditorPane(title: "批量输入", text: $model.batchInput, syntax: false,
                               placeholder: "每行一个时间戳或日期\n最多 1000 行 / 128 KB")
                    EditorPane(title: "批量结果", text: .constant(model.batchOutput), editable: false, syntax: false)
                }
            case .difference: differencePanes
            }
            Divider()
            WorkspaceStatus(message: model.message, isError: model.isError, isProcessing: model.isProcessing && model.mode == .batch,
                            counts: model.mode == .batch ? "最多 1000 行" : "1900–9999 年")
        }
        .background(WorkspaceStyle.background)
        .task {
            while !Task.isCancelled {
                if !model.isClockPaused { model.now = Date() }
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
            }
        }
    }

    private var clockBar: some View {
        WorkspaceToolbar {
            Text(model.isClockPaused ? "已暂停" : "当前").foregroundStyle(.secondary).frame(width: 38)
            Text(model.currentSeconds).monospacedDigit().textSelection(.enabled)
            Text("秒").foregroundStyle(.secondary)
            CopyButton(text: model.currentSeconds)
            Divider().padding(.vertical, 7)
            Text(model.currentMilliseconds).monospacedDigit().textSelection(.enabled)
            Text("毫秒").foregroundStyle(.secondary)
            CopyButton(text: model.currentMilliseconds)
            Spacer(minLength: 4)
            Button(model.isClockPaused ? "继续" : "暂停") {
                model.isClockPaused.toggle()
                if !model.isClockPaused { model.now = Date() }
            }
        }
    }

    private var conversionPanes: some View {
        HSplitView {
            formPane("输入") {
                inputSection("时间戳 → 日期", hint: "整数时间戳（\(model.unit.rawValue)）", text: $model.epochInput,
                             identifier: "timestamp-epoch-input")
                inputSection("日期 → 时间戳", hint: "yyyy-MM-dd HH:mm:ss[.SSS]", text: $model.dateInput,
                             identifier: "timestamp-date-input")
                guidance
            }
            formPane("结果") {
                resultSection("日期 · \(model.timeZoneID)", value: model.dateOutput, error: model.epochError)
                resultSection("时间戳 · \(model.unit.rawValue)", value: model.epochOutput, error: model.dateError)
            }
        }
    }

    private var differencePanes: some View {
        HSplitView {
            formPane("输入日期") {
                inputSection("开始时间", hint: "yyyy-MM-dd HH:mm:ss[.SSS]", text: $model.startInput,
                             identifier: "timestamp-start-input")
                inputSection("结束时间", hint: "yyyy-MM-dd HH:mm:ss[.SSS]", text: $model.endInput,
                             identifier: "timestamp-end-input")
                guidance
            }
            formPane("时间差结果") {
                resultSection("结束 − 开始", value: model.differenceOutput, error: model.differenceError)
                Text("按实际经过时间计算；跨夏令时可能与钟面时间差不同。一天固定为 24 小时。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var guidance: some View {
        Text("标准日期按所选时区解释。ISO 8601 示例：2026-09-26T12:30:00.123+08:00，显式偏移优先。" +
             (model.mode == .difference ? "" : "\n\n毫秒模式保留小数；秒模式向下取整。单位不会自动猜测。"))
            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }

    private func formPane<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack { Text(title).fontWeight(.medium); Spacer() }
                .font(.system(size: 12)).padding(.horizontal, 8).frame(height: WorkspaceStyle.paneHeaderHeight)
                .background(WorkspaceStyle.chrome)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12, content: content)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }
        }.frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
    }

    private func inputSection(_ title: String, hint: String, text: Binding<String>, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).fontWeight(.medium)
                Spacer()
                Button("清空") { text.wrappedValue = "" }.disabled(text.wrappedValue.isEmpty)
                    .accessibilityLabel("清空" + title)
            }
            TextField(hint, text: text).textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced)).accessibilityIdentifier(identifier)
        }.font(.system(size: 12)).controlSize(.small).frame(minHeight: 58, alignment: .top)
    }

    private func resultSection(_ title: String, value: String, error: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).foregroundStyle(.secondary).lineLimit(1).help(title)
                Spacer()
                CopyButton(text: value).fixedSize()
            }
            Text(error.isEmpty ? (value.isEmpty ? "—" : value) : error)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(error.isEmpty ? Color.primary : .red)
                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }.font(.system(size: 12)).controlSize(.small).frame(minHeight: 58, alignment: .top)
    }
}
