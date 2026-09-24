# macOS 开发者工具箱 Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task in the current session. Steps use checkbox syntax for tracking.

**Goal:** 交付可本地运行的 NsToolBox 原生 macOS 首版应用，包含 JSON 和编码工具。

**Architecture:** SwiftUI 主窗口和状态管理，AppKit 文本编辑器负责着色；独立 Foundation 核心模块负责 JSON 解析、序列化、结构化比较及编码转换。Swift Package 提供可测试模块与命令行构建，Xcode 工程使用同一份源文件。

**Tech Stack:** Swift 5.9+、SwiftUI、AppKit、Foundation、Swift Package Manager、Xcode。

**Spec:** `docs/superpowers/specs/2026-09-25-developer-toolbox-macos-design.md`

## Global Constraints

- macOS 13 及以上。
- Intel 与 Apple Silicon；Universal 2 应用包。
- 首版不引入第三方依赖；所有输入在本地处理。
- JSON 对象字段顺序忽略，数组顺序敏感，数字按数值比较。
- 左右编辑器独立滚动；无效输入清除差异并显示行列信息。
- 界面为简体中文，标准系统控件支持浅色与深色外观。
- 当前只有 Command Line Tools：命令行打包必须可用；Xcode 工程实际构建需在安装完整 Xcode 后另行验证。

## 文件与接口

```text
Package.swift                          核心、应用和测试目标
Sources/ToolboxCore/JSONValue.swift     类型、路径、解析错误
Sources/ToolboxCore/JSONParser.swift    严格解析、UTF-16 源范围和错误行列
Sources/ToolboxCore/JSONWriter.swift    确定性序列化、格式化与压缩
Sources/ToolboxCore/JSONDiff.swift      结构化差异及左右源范围
Sources/ToolboxCore/TextCodec.swift     UTF-8 Base64、URL 百分号编解码
Sources/NsToolBox/NsToolBoxApp.swift    应用入口、导航、菜单
Sources/NsToolBox/CodeEditor.swift      NSTextView 桥接及着色
Sources/NsToolBox/JSONToolView.swift    JSON 功能页面
Sources/NsToolBox/JSONToolModel.swift   防抖、后台计算与过期结果丢弃
Sources/NsToolBox/EncodingToolView.swift 编解码页面与状态
Sources/NsToolBox/SharedViews.swift     编辑区、状态、复制反馈
Tests/ToolboxCoreTests/                核心行为测试
scripts/build-app.sh                   双架构编译、合并、打包、本地签名
Resources/Info.plist                   应用元数据和最低系统版本
NsToolBox.xcodeproj/project.pbxproj    原生 app 工程
README.md                             构建、使用、已知边界
```

### Task 1：无损 JSON 与编码核心

接口：`JSONParser.parse(_ text: String) throws -> JSONDocument`；`JSONWriter.write(_ value: JSONValue, pretty: Bool) -> String`；`TextCodec.encode/decode(_:kind:) throws -> String`。`JSONDocument` 包含树和以类型化 `JSONPath` 为键的 `NSRange`，范围使用 UTF-16，与 NSTextView 一致。

- [ ] 创建 Package.swift、.gitignore 和核心目标；先写以下行为测试并运行确认缺失功能失败。

```swift
let document = try JSONParser.parse(#"{"a":1,"text":"中文😀"}"#)
XCTAssertEqual(JSONWriter.write(document.value, pretty: false), #"{"a":1,"text":"中文😀"}"#)
XCTAssertThrowsError(try JSONParser.parse(#"{"a":01}"#))
XCTAssertThrowsError(try JSONParser.parse("{\n  \"a\": }"))
XCTAssertEqual(try TextCodec.decode("5Lit5paH", kind: .base64), "中文")
XCTAssertEqual(try TextCodec.encode("a+b /", kind: .url), "a%2Bb%20%2F")
XCTAssertThrowsError(try TextCodec.decode("%FF", kind: .url))
```

- [ ] 实现严格 JSON 语法、错误行列、确定性键排序和源范围；限制嵌套深度，避免栈溢出。
- [ ] 实现 JSON 数字处理。保留原始数字词法文本避免 Decimal 表示范围或精度导致格式化丢失值；普通数字以数值语义比较，大数也需精确比较。此为设计模型的精度修正，不改变用户功能。
- [ ] 实现编码服务。URL 按 RFC 3986 非保留字符集编码文本（适合参数值）；解码不把 `+` 当空格。Base64 拒绝非法字符、错误填充及无效 UTF-8，可忽略 ASCII 空白。
- [ ] 运行 `swift test`，或在 CLT 缺少 XCTest 时用 `swiftc` 编译同一核心的无依赖行为测试运行器；记录准确结果并提交核心增量。

### Task 2：结构化差异与定位

接口：`JSONDiff.compare(_ left: JSONDocument, _ right: JSONDocument) -> [JSONDifference]`。差异含类型（added/removed/modified）、类型化路径、左右可选 UTF-16 范围；对象按键递归，数组按索引递归。

- [ ] 先写以下行为测试，确认失败。

```swift
let left = try JSONParser.parse(#"{"a":1,"b":[true,2]}"#)
let right = try JSONParser.parse(#"{"b":[false,2,3],"a":1.0}"#)
let changes = JSONDiff.compare(left, right)
XCTAssertEqual(changes.map(\.path.description), ["$.b[0]", "$.b[2]"])
XCTAssertEqual(changes.map(\.kind), [.modified, .added])
```

- [ ] 实现稳定顺序的差异列表；类型不同标记整个节点。特殊字段名使用 JSON 字符串方括号路径，避免点号字段产生歧义。
- [ ] 补充 Unicode/emoji 源范围、根节点类型变化、空容器、数组删除、极大数字比较测试；运行测试并提交。

### Task 3：原生窗口与实时 JSON 编辑器

接口：`CodeEditor(text: Binding<String>, highlights: [EditorHighlight], editable: Bool)`；JSONToolModel 为 MainActor ObservableObject，后台队列解析、防抖 250ms、请求序号校验防止旧结果覆盖新输入。

- [ ] 在可测试边界先覆盖输入错误后清除旧结果，以及快速输入只应用最后一次结果。
- [ ] 构建 SwiftUI NavigationSplitView 及工具路由，保持切换页面时的输入状态。
- [ ] JSON 页提供格式化/压缩/校验/对比模式，双栏编辑、差异图例与带路径的差异列表；列表选择定位左右范围。
- [ ] NSTextView 关闭智能引号等文本替换，使用等宽字体、水平/垂直滚动；着色使用布局管理器临时属性，避免重写输入或破坏撤销。
- [ ] 支持 JSON 语法色、差异背景、行列错误提示；格式化和压缩操作保留源输入并输出结果，对比格式化左右两侧。
- [ ] 编译应用目标验证 macOS 13 API 兼容性；在无原生 UI 自动化时明确记录人工验收边界。

### Task 4：编码页面、发布构建与文档

- [ ] Base64/URL 页面提供编码/解码、输入输出、复制和清空；失败保留输入、清空旧输出，显示可读错误。
- [ ] 生成 Xcode app 工程：`MACOSX_DEPLOYMENT_TARGET = 13.0`，`ARCHS = "$(ARCHS_STANDARD)"`，Release `ONLY_ACTIVE_ARCH = NO`。
- [ ] 创建可重复构建脚本，分别运行下面命令后用 lipo 合并、复制 Info.plist 并对 app 做 ad-hoc 签名。

```sh
swift build -c release --triple x86_64-apple-macosx13.0 --product NsToolBox
swift build -c release --triple arm64-apple-macosx13.0 --product NsToolBox
lipo -info build/NsToolBox.app/Contents/MacOS/NsToolBox
codesign --verify --deep --strict build/NsToolBox.app
```

- [ ] README 写明 SwiftPM/Xcode 构建、功能规则、本地签名与正式分发区别。
- [ ] 完整运行核心测试、状态测试、打包脚本、架构和最低版本检查；尝试启动 app 并确认进程存活。
- [ ] 复查修改与设计一致，修复发现的问题；更新本计划完成标记并提交。最终报告产物路径、测试结果、实际验证限制。

## 自检

任务 1 覆盖 JSON/编码处理和错误行为，任务 2 覆盖结构化 Diff，任务 3 覆盖界面与数据流，任务 4 覆盖构建与使用说明。无网络、文件导入、同步滚动、账号等范围外功能。
