# 开发问题列表与修复指南

维护 NsToolBox 开发中遇到的问题、定位方法和当前状态。先按索引定位，再复现与验证；同一问题复发更新原条目。

首次整理：2026-09-25。以下历史条目的发现、更新日期均为 2026-09-25；依据开发时的真实错误、源码和 [首版验证记录](../superpowers/validation/2026-09-25-macos-v1.md) 整理。本轮仅编写文档，没有重新运行所有历史验证；后续更新须在对应条目注明新日期。

## 维护与关闭规则

1. 新问题使用 [模板](ISSUE_TEMPLATE.md)，按最大编号加一新增详情和索引。复发问题追加原条目的时间线。
2. 区分现象、证据和假设；未解决也记录失败尝试与下一步，不能把猜测写成根因。
3. 修复与记录在同一任务中更新；“已解决”须有原始失败场景的验证依据，用户可见问题还需实际显示确认。
4. 保留历史错误结论及其纠正，不把失败无痕改成成功。索引与详情状态保持一致。
5. 持续维护要求见根目录 [AGENTS.md](../../AGENTS.md)。

| 状态 | 定义 |
| --- | --- |
| 待定位 | 已发现，根因或复现条件不清楚 |
| 修复中 | 正在实施修复 |
| 待验证 | 已采取措施，关键测试或验收未完成 |
| 已解决 | 修复完成，原始问题验证通过 |
| 已规避 | 当前路径可用，原环境限制或根因尚未消除 |

## 问题索引

| 编号 | 模块 | 问题 / 检索关键词 | 状态 |
| --- | --- | --- | --- |
| [NST-001](#nst-001) | 图标 / 构建 | Finder、Dock 无图标；包目录时间不更新 | 待验证 |
| [NST-002](#nst-002) | 测试环境 | no such module 'XCTest'；xcodebuild requires Xcode | 已规避 |
| [NST-003](#nst-003) | SDK | SwiftBridging 重定义；SDK is not supported by the compiler | 已规避 |
| [NST-004](#nst-004) | 构建排查 | SwiftUI 编译无输出，被误判为阻塞 | 已解决 |
| [NST-005](#nst-005) | Base64 | CRLF 导致有效输入解码失败 | 已解决 |
| [NST-006](#nst-006) | JSON 状态 | 旧差异高亮残留；过期异步结果风险 | 已解决 |
| [NST-007](#nst-007) | 编辑器 | 语法色相互覆盖；着色影响撤销的风险 | 已解决 |
| [NST-008](#nst-008) | JSON 数字 | Decimal / Double 精度和范围不足 | 已解决 |
| [NST-009](#nst-009) | 打包 | unsupported target architecture；变量未展开 | 已解决 |
| [NST-010](#nst-010) | 打包 | lipo: unknown architecture specification flag | 已解决 |
| [NST-011](#nst-011) | 构建流程 | 构建运行中删除源码；stat error | 已解决 |
| [NST-012](#nst-012) | Swift 编译 | 可选类型模式、throwing autoclosure、Actor 隔离 | 已解决 |
| [NST-013](#nst-013) | UI 验证 | 离屏截图缺少系统材质与侧边栏 | 已规避 |
| [NST-014](#nst-014) | 界面规划 | 当前布局不符合用户预期，重新规划并实现 | 待验证 |
| [NST-015](#nst-015) | 编辑器绘制 | 行号尺越界遮住文本、面板标题 | 已解决 |
| [NST-016](#nst-016) | 辅助功能 | 编辑器复用后标签和编辑状态未同步 | 待验证 |
| [NST-017](#nst-017) | UI 测试 | 窗口截图失败、SwiftUI AX 子树为空 | 已规避 |
| [NST-018](#nst-018) | 图片处理规划 | 通用主体去背景 API 不支持 macOS 13 | 已解决 |
| [NST-019](#nst-019) | 图片测试 | 修改 PNG IHDR 不能构造有效超尺寸样本 | 已解决 |
| [NST-020](#nst-020) | SwiftUI | macOS 14 onChange 旧签名弃用警告 | 已解决 |
| [NST-021](#nst-021) | 图片编码 | 无变换 PNG 重编码损失位深与色彩信息 | 已解决 |
| [NST-022](#nst-022) | 图片缓存 | 仅靠 deinit 无法保证退出清理 | 已解决 |
| [NST-023](#nst-023) | 构建产物 | 中断后目录仍保留旧 macOS 13 应用 | 已解决 |
| [NST-024](#nst-024) | 图片预览 | 深色模式结果间歇性呈现白块 | 已规避 |
| [NST-025](#nst-025) | Git 远程 | 推送 GitHub 时本机代理端口不可连接 | 待定位 |

## 通用排查入口

以下命令从仓库根目录执行。先记录环境和当前版本：

~~~sh
git status --short --branch
git log -5 --oneline
sw_vers
uname -m
swift --version
xcode-select -p
xcrun --show-sdk-path
~~~

按问题选择验证，不把暂时无输出当成失败：

~~~sh
swift run ToolboxCoreTests
swift run ToolboxImageTests
swift run ToolboxUITests
# 需要登录图形会话，会创建临时窗口和 build/previews 图片
swift run ToolboxUITests --render
# 覆盖 build/NsToolBox.app 并刷新注册，不会重启正在运行的应用
./scripts/build-app.sh
~~~

检查构建产物：

~~~sh
plutil -p build/NsToolBox.app/Contents/Info.plist
lipo build/NsToolBox.app/Contents/MacOS/NsToolBox -archs
xcrun vtool -show-build build/NsToolBox.app/Contents/MacOS/NsToolBox
codesign --verify --deep --strict --verbose=2 build/NsToolBox.app
~~~

预期：架构包含 x86_64、arm64，两架构 minos 均为 14.0，签名检查退出码为 0。交叉编译不等于实机运行；当前验收边界见 [图片处理验证记录](../superpowers/validation/2026-09-26-image-tools.md)，历史 macOS 13 记录保留原结论。

## 问题详情

<a id="nst-001"></a>

### NST-001 · Finder / Dock 不显示应用图标

- **状态 / 来源**：待验证；用户多次反馈两个位置均无图标。
- **环境与影响**：macOS 26.7、Intel，命令行构建的 build/NsToolBox.app；Finder 文件图标和 Dock 图标受影响。
- **现象与复现**：加入图标并多次原地构建后仍无图标。系统 API 与用户实际显示不一致，验证工具尚未稳定复现显示异常。
- **已确认事实**：包内 ICNS、CFBundleIconFile、签名正常；ICNS 含 10 个尺寸；注册指向正确路径；最近一次原始资源、NSWorkspace、NSRunningApplication 的 16～512 像素渲染均正常。
- **独立缺陷**：原脚本只覆盖 Contents，重复构建前后 .app 目录 st_mtime_ns 不变，断言失败；修复后递增，签名有效。
- **未确认根因**：目录时间不变可能影响显示刷新，但尚不能证明它解释了全部图标异常。

**排查与修复指南**

1. 确认正在查看、运行的是当前构建产物，区分 Applications 副本和 SwiftPM 裸可执行文件。
2. 执行通用产物检查，再核对图标及目录时间：

~~~sh
cmp Resources/AppIcon.icns build/NsToolBox.app/Contents/Resources/AppIcon.icns
stat -f '%Sm %N' -t '%Y-%m-%d %H:%M:%S' build/NsToolBox.app
~~~

3. 重新执行打包脚本；现已在签名后更新包时间，并用 lsregister -f 注册这一应用，留意注册失败警告。
4. 在 Finder / Dock 实际验收。重启应用前保存输入，当前版本退出后不保留输入。API 读取正常不能代替验收。
5. 若仍异常，记录位置、实际路径、显示样式和可用截图，检查旧副本及显示配置差异，再决定实验。不要无依据清空全系统缓存。

| 日期 | 措施与证据 | 结果 |
| --- | --- | --- |
| 2026-09-25 | 检查资源、尺寸和签名 | 通过，仅证明资源正确 |
| 2026-09-25 | 新进程 API 图标正常，曾推断恢复 | 用户随后反馈两处仍不显示；该结论撤回 |
| 2026-09-25 | 重复构建比较包目录时间 | 修复前不变，修复后递增；签名通过 |
| 2026-09-25 | 重新注册、刷新 Finder 目录、重启当前用户 Dock | 操作完成，应用进程保留；真实显示待确认 |

- **关联**：[打包脚本](../../scripts/build-app.sh)、[图标配置](../../Resources/Info.plist)、[设计说明](../../Resources/AppIcon-design.md)；提交 4e46703。
- **下一步 / 关闭条件**：用户的 Finder、Dock 都显示“大乱炖”，并复验再次构建后的显示；没有证据前保持待验证。

<a id="nst-002"></a>

### NST-002 · CLT 环境缺少 XCTest / Xcode

- **状态 / 来源**：已规避；真实编译错误。
- **环境与复现**：Swift 6.3.3，开发目录为 CommandLineTools。早期 swift test 报 no such module 'XCTest'；xcodebuild -version 要求完整 Xcode。
- **根因**：此环境缺少完整 Xcode 的测试组件；不能由此推断 SwiftUI 无法编译。
- **修复指南**：本工程测试已改为 SwiftPM 可执行目标，用 swift run ToolboxCoreTests 和 swift run ToolboxUITests。需要 XCTest/Xcode GUI 时使用兼容的完整 Xcode，先核对开发目录，不盲目切换全局工具链。
- **验证**：2026-09-25 核心 11 组和 UI 测试、命令行双架构构建通过；完整 Xcode 构建未执行。
- **关联**：[Package.swift](../../Package.swift)、[核心测试](../../Sources/ToolboxCoreTests/main.swift)、[UI 测试](../../Sources/ToolboxUITests/StateTests.swift)；cf08300、ed3319e。
- **防复发**：当前工程测试入口不是 swift test，遵循 README。

<a id="nst-003"></a>

### NST-003 · 旧 SDK 与编译器不兼容

- **状态 / 来源**：已规避；真实编译错误。
- **复现**：Swift 6.3.3 手工指定 MacOSX13.3.sdk 做 SwiftUI 类型检查。
- **错误与证据**：redefinition of module 'SwiftBridging'、could not build module 'CoreFoundation'、this SDK is not supported by the compiler；错误指出 SDK 来自 Swift 5.8。
- **修复指南**：使用 xcrun --show-sdk-path 对应默认 SDK，通过 Package.swift、target triple 和 MACOSX_DEPLOYMENT_TARGET 设置最低 13.0。支持 macOS 13 不要求使用 13 SDK；确需旧 SDK 时使用匹配工具链。
- **验证**：2026-09-25 默认 26.5 SDK 双架构构建成功，vtool 显示 minos 13.0；旧组合未修复。
- **关联**：[打包脚本](../../scripts/build-app.sh)、[Xcode 工程](../../NsToolBox.xcodeproj/project.pbxproj)；d912b7e。
- **防复发**：分别记录编译器、SDK 与部署版本。

<a id="nst-004"></a>

### NST-004 · 编译无输出被误判为阻塞

- **状态 / 来源**：已解决；排障流程问题，非已证实的编译器故障。
- **触发**：首次 SwiftUI / Release 编译数十秒无输出，被过早中断，一度误判为“缺少 Xcode 无法构建”。
- **定位证据**：后续 swift-frontend 持续占用 CPU，默认 SDK 构建完成；首轮双架构 Release 曾分别耗时约 83 和 92 秒。
- **修复指南**：观察进程、输出及最终退出码，保留构建继续执行；不要同时修改其正在读取的源码。真实错误按 NST-003、NST-011 排查。
- **验证**：2026-09-25 继续等待后编译链接成功，后续增量构建缩短。
- **关联**：[构建入口](../../scripts/build-app.sh)；流程纠正，无独立提交。
- **防复发**：工具等待超时不等于命令失败。

<a id="nst-005"></a>

### NST-005 · Base64 的 CRLF 未被移除

- **状态 / 来源**：已解决；真实行为测试失败。
- **复现与影响**：输入 `5Li t\n5paH\r\n`（转义表示真实换行），预期“中文”，曾抛出 CodecError.invalidBase64。
- **根因证据**：Swift Character 可把 CRLF 合为一个字符；分别过滤 CR、LF 会漏掉组合。标量检查发现末尾仍有 13、10。
- **修复指南**：使用 Character.isWhitespace 过滤空白，继续严格检查字符、填充和 UTF-8，不忽略其他非法字符。
- **验证**：核心 testBase64TextAndWhitespace 覆盖 CRLF、中文、空串、非法填充、非 UTF-8；2026-09-25 通过。
- **关联**：[TextCodec.swift](../../Sources/ToolboxCore/TextCodec.swift)、[核心测试](../../Sources/ToolboxCoreTests/main.swift)；cf08300。
- **防复发**：保留 CRLF 样例，不只测试 LF。

<a id="nst-006"></a>

### NST-006 · 输入变化后旧差异仍显示

- **状态 / 来源**：已解决；状态测试复现。
- **复现**：左右输入 `{"x":1}`、`{"x":2}`，出现差异后将右侧改为 `{`；防抖期间旧范围仍存在。
- **证据与影响**：Changing input must immediately clear stale source ranges 断言失败；可能标错新文本，也需要防止过期异步结果覆盖。
- **修复指南**：输入或模式变化立即清除旧输出、差异、错误；取消待执行任务，递增请求序号；后台结果只在序号匹配时写回主线程。清空同样使旧请求失效。
- **验证**：swift run ToolboxUITests 验证立即清除、错误恢复、快速输入、模式切换与清空；2026-09-25 通过。
- **关联**：[JSONToolModel.swift](../../Sources/ToolboxUI/JSONToolModel.swift)、[StateTests.swift](../../Sources/ToolboxUITests/StateTests.swift)；ed3319e。
- **防复发**：同时验证等待期间和最终结果。

<a id="nst-007"></a>

### NST-007 · 语法着色覆盖与撤销风险

- **状态 / 来源**：已解决；审查发现并补充验证，没有发布后用户数据损失的证据。
- **触发**：对 `{"key":"true 123","x":1}` 分别执行字符串、常量、数字正则，后面的规则可能覆盖字段名与字符串内部颜色。
- **另一风险**：反复改写 NSTextStorage 属性可能干扰撤销。
- **修复指南**：单次 token 匹配，按上下文区分键名/字符串/数字/常量；使用 NSLayoutManager 临时属性，保留文本和输入法组合态。
- **验证**：testEditorStylingAndUndo 检查键名色、字符串内常量颜色，以及编辑后撤销恢复原文；2026-09-25 通过。
- **关联**：[CodeEditor.swift](../../Sources/ToolboxUI/CodeEditor.swift)、[UI 测试](../../Sources/ToolboxUITests/StateTests.swift)；ed3319e。
- **防复发**：颜色与撤销都要验证，不能只截图。

<a id="nst-008"></a>

### NST-008 · JSON 数字精度与范围不足

- **状态 / 来源**：已解决；设计审查中预防，未记录发布后的数据损失。
- **触发与影响**：超长整数、1e400、极大指数经 Double / Decimal 中转可能舍入或超范围，导致格式化改变值、对比误判。
- **修复指南**：JSONNumber 保留原始词法文本，序列化输出原文；比较使用符号、有效数字和精确指数规范化，不转为浮点数。
- **验证**：核心 testFormatPreservesUnicodeAndLargeNumbers、testNumericEquality、testHugeExponentsAndPreciseIntegers 覆盖大数保真、相邻超长整数、1 与 1.0 相等；2026-09-25 通过。
- **关联**：[JSONValue.swift](../../Sources/ToolboxCore/JSONValue.swift)、[JSONWriter.swift](../../Sources/ToolboxCore/JSONWriter.swift)、[核心测试](../../Sources/ToolboxCoreTests/main.swift)；cf08300、31b7b21。
- **防复发**：同时检查序列化与比较，不默认 Foundation 数字类型总是无损。

<a id="nst-009"></a>

### NST-009 · Shell 变量被转义为字面量

- **状态 / 来源**：已解决；真实打包错误。
- **现象与根因**：unsupported target architecture，错误内显示未展开的 arch 变量；生成脚本时多保留了反斜杠。
- **修复指南**：检查最终脚本，使变量在双引号内正常展开；当前使用 `"$target_arch-apple-macosx13.0"`。分别处理模板层和 Shell 层转义。
- **验证**：2026-09-25 两架构实际构建及 lipo 检查通过。
- **关联**：[build-app.sh](../../scripts/build-app.sh)；修复后版本包含在 d912b7e。
- **防复发**：zsh -n 只查语法，不能代替实际变量展开路径的执行。

<a id="nst-010"></a>

### NST-010 · lipo 将路径当成架构

- **状态 / 来源**：已解决；真实打包错误。
- **错误**：unknown architecture specification flag: /.../NsToolBox in specifying -verify_arch operation。
- **根因**：文件路径放在 -verify_arch 的变长架构参数之后，被读成架构名。
- **修复指南**：文件在前，使用 `lipo "$binary" -verify_arch "$target_arch"`。二进制路径用 SwiftPM --show-bin-path 获取，不能任意搜索回退到另一架构。
- **验证**：2026-09-25 单架构、合并双架构和签名检查通过。
- **关联**：[build-app.sh](../../scripts/build-app.sh)；d912b7e。
- **防复发**：验证实际架构，不仅验证文件存在。

<a id="nst-011"></a>

### NST-011 · 构建运行中删除源文件

- **状态 / 来源**：已解决；真实构建错误。
- **现象**：早期测试还在编译临时 Module.swift，该文件已删除，报 stat error: No such file or directory (2)。
- **根因**：工具返回运行会话后被误认为命令已结束，编译与源码变更发生竞态。
- **修复指南**：确认构建完成或安全停止，再删改它读取的源码；重新验证，不把竞态错误当作预期功能测试失败。
- **验证**：后续顺序执行消除此错误；随后暴露独立类型/环境问题，最终核心测试通过。
- **关联**：[核心源码](../../Sources/ToolboxCore)、[Package.swift](../../Package.swift)；流程纠正，无独立提交。
- **防复发**：同一源码的编辑和构建顺序执行，独立只读检查才可并行。

<a id="nst-012"></a>

### NST-012 · Swift 类型与 Actor 隔离错误

- **状态 / 来源**：已解决；首版编译错误/警告。
- **环境**：Swift 6.3.3，项目采用 Swift 5 语言模式。

| 错误 / 触发 | 原因 | 修复 |
| --- | --- | --- |
| ClosedRange<Int> cannot match values of type 'UInt16?' | 对可选 UTF-16 直接做范围匹配 | 使用 `case let unit? where ...` 解包 |
| call can throw, but it is executed in a non-throwing autoclosure | 断言自动闭包不允许抛错 | helper 接收 Bool，必要时先 try 再断言 |
| 'try' cannot appear to the right of a non-assignment operator | 比较表达式内错误放置 try | 分别解析左右值再比较 |
| call to main actor-isolated static method ... in a synchronous nonisolated context | 纯计算方法继承模型的 MainActor 隔离 | 纯计算标为 nonisolated，状态仍在主线程更新 |
| nil is not compatible with closure result type 'EditorHighlight' | 类型变化后调用仍有旧参数，导致推断报错 | 同步构造参数，显式指定 compactMap 返回 EditorHighlight? |

- **验证**：2026-09-25 核心、UI 目标及双架构应用编译通过。
- **关联**：[JSONParser.swift](../../Sources/ToolboxCore/JSONParser.swift)、[核心测试](../../Sources/ToolboxCoreTests/main.swift)、[JSONToolModel.swift](../../Sources/ToolboxUI/JSONToolModel.swift)、[JSONToolView.swift](../../Sources/ToolboxUI/JSONToolView.swift)；cf08300、ed3319e。
- **防复发**：从首个真实类型错误排查，不关闭并发检查来规避线程安全。

<a id="nst-013"></a>

### NST-013 · 离屏截图不能证明完整显示效果

- **状态 / 来源**：已规避；原生渲染观察。
- **复现与影响**：--render 用离屏 NSHostingView 生成图片，部分系统材质/侧边栏未完整出现，不能据此判定列表无数据或界面已验收。
- **证据**：原生检查有 3 行；三个工具切换、输入输出及输入保留断言通过。
- **处理指南**：截图辅助看布局，真实控件验证行为；系统图标与材质需在用户原场景确认。图标状态见 NST-001。
- **验证**：2026-09-25 原生交互断言通过；离屏限制未消除，完整人工外观矩阵未执行。
- **关联**：[StateTests.swift](../../Sources/ToolboxUITests/StateTests.swift)、[首版验证记录](../superpowers/validation/2026-09-25-macos-v1.md)；ed3319e。
- **防复发**：注明每种验证的证明范围，不将单个工具结果扩展成全面验收。

<a id="nst-014"></a>

### NST-014 · 当前布局不符合用户预期

- **发现 / 更新日期**：2026-09-25 / 2026-09-25。
- **状态 / 来源**：待验证；用户反馈，属于设计需求偏差，尚未认定为代码缺陷。
- **环境与影响**：当前 macOS 应用；用户认为整体布局不符合预期，要求停止开发，先重新规划界面。
- **现象与复现**：当前左栏直接列出 JSON、Base64、URL；用户希望左栏改为工具集分类，三个工具移到主工作区顶部的二级工具栏。双栏内容采用左侧输入、右侧结果，对比时两侧输入。
- **定位与根因**：已确认现有导航层级与用户期望不符，且需采用代码编辑器式的紧凑、高信息密度风格；不属于已确认的布局渲染故障。
- **处理指南**：按已批准的 [紧凑工作区规划](../superpowers/specs/2026-09-25-compact-workspace-design.md) 实现分类导航、顶部工具栏、统一双栏、行号与差异面板。
- **验证**：状态、行号、撤销与组合态测试通过；真实窗口点击、模式标签、单侧清空撤销、格式化撤销、校验定位均通过。已检查默认 / 最小窗口与浅深色截图，用户对最终布局的验收仍待确认。完整结果见 [紧凑工作区验证记录](../superpowers/validation/2026-09-25-compact-workspace.md)。
- **关联**：[主界面](../../Sources/ToolboxUI/ToolboxRootView.swift)、[JSON 页面](../../Sources/ToolboxUI/JSONToolView.swift)、[编解码页面](../../Sources/ToolboxUI/EncodingToolView.swift)。
- **下一步 / 关闭条件**：用户打开本次构建并确认布局符合预期后关闭；技术验证不代替需求验收。

| 日期 | 操作或新证据 | 结果与状态变化 |
| --- | --- | --- |
| 2026-09-25 | 用户要求暂停开发并重新规划布局 | 待定位；进入需求澄清 |
| 2026-09-25 | 用户逐步确认分类导航、顶部工具栏、统一双栏与紧凑风格 | 已形成规划草案，等待整体审阅；未恢复开发 |
| 2026-09-25 | 用户明确批准按规划实现 | 修复中；恢复开发与验证 |
| 2026-09-25 | 实现并通过原生交互及窗口截图检查 | 待验证；等待用户布局验收 |

<a id="nst-015"></a>

### NST-015 · 行号尺越界绘制遮住文本与面板标题

- **发现 / 更新日期**：2026-09-25 / 2026-09-25。
- **状态 / 来源**：已解决；紧凑布局开发中的真实窗口截图复现。
- **环境与影响**：Intel、macOS 26.7、AppKit NSRulerView；双栏中行号存在，但编辑文本、标题和复制 / 清空按钮消失。
- **复现**：显示带原生行号尺的 JSON 对比页，输入两侧有效 JSON；模型和 glyph 布局正常，截图仍只有行号。
- **定位与根因**：行号尺直接填充 drawHashMarksAndLabels 传入的 dirty rect，没有限制到自身 bounds；绘制覆盖邻接区域。只增加尺内裁剪后，文本、标题和按钮在真实窗口截图中同时恢复。
- **失败尝试**：将 textContainer 改为有限大尺寸不能恢复显示，已撤回；单纯强制布局、displayIfNeeded 也无效。
- **修复指南**：保存图形上下文，使用 bounds 设置 clip，只绘制 bounds 与 dirty rect 的交集，结束恢复上下文。避免依赖调用方隐式裁剪。
- **验证**：真实窗口 json-compare、base64 截图恢复正常；新增 bitmap 回归，验证越界 dirty rect 不覆盖尺外像素且不泄漏 clip。回归在 `swift run ToolboxUITests --render --capture` 中通过（退出码 0）。
- **关联**：[CodeEditor.swift](../../Sources/ToolboxUI/CodeEditor.swift)、[EditorTests.swift](../../Sources/ToolboxUITests/EditorTests.swift)。
- **防复发**：自定义 AppKit 绘制显式裁剪，状态与布局断言之外仍检查真实窗口。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-25 | 窗口截图发现行号以外内容缺失 | 复现成功 |
| 2026-09-25 | 有限容器尺寸与强制布局 | 无效 |
| 2026-09-25 | 仅限制行号尺绘制范围并重新截图 | 文本、标题、按钮恢复；已解决 |

<a id="nst-016"></a>

### NST-016 · 复用编辑器未同步辅助功能名称和编辑状态

- **发现 / 更新日期**：2026-09-25 / 2026-09-25。
- **状态 / 来源**：待验证；代码审查发现，未收到真实 VoiceOver 用户故障反馈。
- **环境与影响**：SwiftUI NSViewRepresentable 复用 NSTextView；JSON 格式化 / 压缩 / 对比与编码 / 解码模式切换。
- **现象与复现**：左侧视觉标题随模式变化，但 accessibilityLabel 仅初始化设置；更新文本时仍使用旧 isEditable，存在只读转编辑时拒绝替换的风险。
- **定位与根因**：makeNSView 内设置的属性不会随 SwiftUI 参数自动同步；updateNSView 缺少同步，且状态设置顺序不当。
- **修复指南**：先同步 isEditable 和 accessibilityLabel，再执行模型文本替换、样式与选区更新，保留 marked text 保护。
- **验证**：编辑器状态测试通过；真实宿主模式切换、标签与只读属性断言已通过（退出码 0）；真实 VoiceOver 朗读尚未人工验收。
- **关联**：[CodeEditor.swift](../../Sources/ToolboxUI/CodeEditor.swift)、[工作区交互测试](../../Sources/ToolboxUITests/WorkspaceInteractionTests.swift)。
- **下一步**：原生标签断言已通过；真实 VoiceOver 场景仍需人工验收，保持待验证。

<a id="nst-017"></a>

### NST-017 · 命令行 SwiftUI 测试窗口与辅助功能树不完整

- **发现 / 更新日期**：2026-09-25 / 2026-09-25。
- **状态 / 来源**：已规避；真实测试错误与环境限制。
- **环境与影响**：SwiftPM 可执行测试、NSHostingView、macOS 26.7；异步 main 不等于完整 NSApplication 生命周期。
- **现象**：窗口截图报 could not create image from window；SwiftUI accessibilityChildren 为空，分类断言失败，虽然原生视图和实际分类文字存在。
- **定位证据**：测试改为同步 main 启动 NSApplication.run，异步 Task 执行用例后 stop，窗口自身截图成功。SwiftUI AX 子树仍未完整暴露；设置旧 AXManualAccessibility 属性无效，已撤回。
- **修复 / 规避指南**：真实窗口验证启动 AppKit 事件循环；导航测试向自身窗口发送 NSEvent 点击，再验证实际编辑器输入输出与保留结果，不用空 AX 子树推断控件缺失。仅截取测试进程自己的窗口，截图不可用时明确报告。
- **附带编译错误**：NSAccessibility 是具体类型，不能写 any NSAccessibility；需要协议类型时使用 NSAccessibilityProtocol。已修正，最终导航测试不依赖完整 SwiftUI AX 树。
- **验证**：窗口截图返回 0，窗口事件坐标按各视图 isFlipped 转换，并选取按钮实际命中范围；顶部 JSON → Base64 → URL → Base64 → JSON 点击与数据保留断言通过；完整 VoiceOver 树未验证。
- **关联**：[StateTests.swift](../../Sources/ToolboxUITests/StateTests.swift)、[NST-013](#nst-013)。
- **防复发 / 下一步**：区分测试宿主缺陷、截图能力限制与实际界面问题；保留原生视图标签断言和用户场景验收。

**复发时间线**

| 日期 | 操作或新证据 | 结果与下一步 |
| --- | --- | --- |
| 2026-09-25 | 图片工具集执行 `swift run ToolboxUITests --render --capture` | 状态和原生事件断言通过；7 个窗口截图均报 `could not create image from window`、子进程退出 1；重新打开条目 |
| 2026-09-26 | 整理本轮验证边界 | AppKit 生命周期修正未能稳定规避截图失败；当前原因未确认，不推断为界面缺失或权限问题。保留离屏图辅助定位，需恢复窗口截图或人工检查真实应用 |

2026-09-26 恢复工作后再次执行同一命令，7 个真实窗口截图全部退出 0；截图恢复原因未确认，不能归因为权限或锁屏。已检查图片页面浅深色真实窗口。深色结果白块在真实窗口仍出现，已从截图问题中分离为 [NST-024](#nst-024)。`--capture` 目前只报告单张截图返回码，主测试退出 0 仅表示行为断言通过，不能当作截图成功。

恢复验证：2026-09-26 重跑原命令，7 个截图退出 0；当前路径可用，间歇性原因未确认，状态改为已规避。

<a id="nst-018"></a>

### NST-018 · 通用主体去背景与 macOS 13 的兼容边界

- **发现 / 更新日期**：2026-09-25 / 2026-09-26。
- **状态 / 来源**：已解决；规划时 SDK 能力审查，非已发布功能故障。
- **环境与影响**：原工程最低 macOS 13；`VNGenerateForegroundInstanceMaskRequest` 从 macOS 14 可用，人像接口不能替代任意主体去背景。
- **定位与根因**：读取 Vision SDK 头文件确认可用性边界；不是单纯架构问题。
- **修复指南**：用户确认最低 macOS 14，Package.swift、Info.plist、Xcode 两配置、构建脚本同步升级；保留原生 Vision 通用主体 / 人像两模式及明确错误。
- **验证**：2026-09-25 当前 Intel / macOS 26.7 上图片测试通过，通用球体保留中心并去背景，人像样本可分割，空白图正确报告无主体。配置和产物复核见 [图片处理验证](../superpowers/validation/2026-09-26-image-tools.md)。Apple Silicon / macOS 14 实机未执行。
- **关联**：[Package.swift](../../Package.swift)、[ImageProcessor.swift](../../Sources/ToolboxImages/ImageProcessor.swift)。实现提交：`e8a8b7a`。
- **下一步**：补实机矩阵；API 版本声明不能代替所有硬件的实际推理验证。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-25 | 发现原最低版本缺少通用抠图 API | 待定位，提出兼容选择 |
| 2026-09-25 | 用户明确最低版本改为 macOS 14 | 实现纯系统算法方案 |
| 2026-09-26 | 归档 Intel 两模式实际推理与配置验证 | 原兼容决策问题已解决；实机矩阵仍待补 |

<a id="nst-019"></a>

### NST-019 · 超尺寸测试样本被识别为损坏 PNG

- **发现 / 更新日期**：2026-09-25 / 2026-09-26。
- **状态 / 来源**：已解决；新增测试实际失败。
- **环境与影响**：Intel、macOS 26.7、Swift 6.3.3；测试试图验证 4000 万像素限制。
- **现象与复现**：仅修改已有 PNG 的 IHDR 尺寸后调用 inspect / process，ImageIO 报损坏而非预期资源上限，断言失败。原错误归类为图片损坏；当时完整底层日志未保留。
- **定位与根因**：头部与压缩像素内容不一致，样本不是合法的大图；不是产品资源检查失效。
- **修复指南**：用 ImageIO 编码有效 8000 × 5001 灰度 PNG，再调用两个 API 断言资源限制；不要伪造头部代替有效编码。
- **验证**：2026-09-25 `swift run ToolboxImageTests --vision-person build/fixtures/astronaut.png` 最后 10/10 组通过（退出 0），含 inspect / process 超限拒绝。
- **关联**：[图片测试](../../Sources/ToolboxImageTests/main.swift)。实现提交：`e8a8b7a`。
- **下一步**：继续使用有效样本测试资源边界，损坏文件单独测试。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-25 | 修改 IHDR 构造超尺寸图 | 未触发预期资源错误，失败 |
| 2026-09-25 | 改为有效灰度 PNG 并运行测试 | 资源上限断言通过 |

<a id="nst-020"></a>

### NST-020 · 最低 macOS 14 后 onChange 旧签名弃用警告

- **发现 / 更新日期**：2026-09-25 / 2026-09-26。
- **状态 / 来源**：已解决；实际编译警告。
- **环境与影响**：macOS 14 部署目标、SDK 26.5；JSON 选区同步和状态详情控件。
- **现象与复现**：`swift run ToolboxUITests` 报 `'onChange(of:perform:)' was deprecated in macOS 14.0: Use onChange with a two or zero parameter action closure instead.`；构建未失败。
- **定位与根因**：旧单参数闭包在新最低版本下产生弃用诊断。
- **修复指南**：JSON 选区清除改用零参数；状态控件用双参数读取新值，行为不变。
- **验证**：2026-09-25 `swift run ToolboxUITests --render --capture` 重新编译无此警告；状态与模式切换断言通过，截图限制另见 NST-017。
- **关联**：[JSONToolView.swift](../../Sources/ToolboxUI/JSONToolView.swift)、[WorkspaceStyle.swift](../../Sources/ToolboxUI/WorkspaceStyle.swift)。实现提交：`e8a8b7a`。
- **下一步**：升级最低版本时检查编译诊断，保留现有交互回归。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-25 | 提升最低版本后编译 | 出现弃用警告 |
| 2026-09-25 | 切换新闭包签名并重新运行 UI 测试 | 警告消失，行为通过 |

<a id="nst-021"></a>

### NST-021 · PNG 无变换处理可能丢失位深和色彩信息

- **发现 / 更新日期**：2026-09-25 / 2026-09-26。
- **状态 / 来源**：已解决；代码审查发现，未收到用户文件损坏反馈。
- **环境与影响**：图片处理首轮实现；16 位或广色域 PNG 在不抠图、尺寸不变时也经过 8 位 sRGB CGContext，与“无损”表述不符。
- **现象与复现**：为 16 位 Display P3 PNG 选择无变换 PNG 输出；原逻辑无条件走 8 位绘制。旧路径的失败测试未单独执行，不能称为已验证的红绿测试。
- **定位与根因**：编码格式无损不代表之前的位深及色彩空间转换无损。
- **修复指南**：输入输出均 PNG、无抠图、尺寸不变、方向正常时保留原始字节，独立生成预览；实际像素变换仍输出 8 位 sRGB，文档明确说明。UI 不再笼统承诺 PNG 无损重编码。
- **验证**：2026-09-25 图片测试 10/10 组通过，新增 16 位 Display P3 样本检查原字节与位深一致，覆盖原尺寸、100% 和相同尺寸参数；EXIF 镜像仍通过。
- **关联**：[ImageProcessor.swift](../../Sources/ToolboxImages/ImageProcessor.swift)、[图片测试](../../Sources/ToolboxImageTests/main.swift)。实现提交：`e8a8b7a`。
- **下一步**：若扩展专业图像工作流，另行实现全管线高位深及色彩管理。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-25 | 审查指出无损承诺与 8 位绘制冲突 | 修复中 |
| 2026-09-25 | PNG 无像素变换直通并新增精度测试 | 字节与位深回归通过 |

<a id="nst-022"></a>

### NST-022 · 图片会话缓存仅依赖析构无法保证退出清理

- **发现 / 更新日期**：2026-09-25 / 2026-09-26。
- **状态 / 来源**：已解决；代码审查发现的生命周期缺口，旧实现未做真实退出残留复现。
- **环境与影响**：SwiftUI StateObject / 串行后台队列；临时目录包含原图副本与结果。
- **现象与复现**：旧清理仅在 deinit 中异步派发，应用终止不保证析构或等待队列；规格要求正常退出清理。
- **定位与根因**：模型生命周期与进程终止不是同一保证；没有明确终止钩子。
- **修复指南**：监听 NSApplication.willTerminateNotification，取消任务、同步等待当前后台系统操作结束，再删除当前模型会话目录；不删除其他会话或用户导出的文件。正常退出可能等待当前图处理完成。
- **验证**：2026-09-25 UI 测试同时检查通知清理与子进程真实 `NSApp.terminate`：保持模型存活、记录缓存路径，退出码 0 后父进程确认目录不存在；通过。人工 Cmd-Q / 强制退出未执行，后者不承诺清理。
- **关联**：[ImageBatchModel.swift](../../Sources/ToolboxUI/ImageBatchModel.swift)、[ImageBatchTests.swift](../../Sources/ToolboxUITests/ImageBatchTests.swift)。实现提交：`e8a8b7a`。
- **下一步**：保留实际 AppKit 退出回归；如需崩溃恢复清理，需单独设计跨实例安全策略。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-25 | 审查发现仅析构清理 | 修复中 |
| 2026-09-25 | 增加终止钩子与真实退出子进程测试 | 缓存目录已删除 |

<a id="nst-023"></a>

### NST-023 · 构建中断后旧应用仍保留在输出目录

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：已解决；恢复任务时实际产物检查。
- **环境与影响**：Universal 2 构建跨工作会话，旧产物最低 macOS 13，新源码要求 14。
- **现象与复现**：恢复后构建会话不可查询（Unknown process id），输出目录存在、签名有效，但 vtool 两架构 minos 仍为 13.0，不能证明新功能已构建。
- **定位与根因**：上轮未取得完整构建成功证据；目录中有效旧产物被保留。中断具体原因未确认。
- **修复指南**：重新执行构建并将日志保存在 build，等待退出 0；同时核对 lipo、vtool、plist 和签名，不能以文件存在代替构建完成。
- **验证**：2026-09-26 `./scripts/build-app.sh` 退出 0；vtool 两架构 minos 14.0，Info.plist 为 14.0，签名有效。
- **关联**：[构建脚本](../../scripts/build-app.sh)、[验证记录](../superpowers/validation/2026-09-26-image-tools.md)。无独立产品代码修复。
- **下一步**：每次交付记录完整构建退出码和产物版本；避免把中断任务的旧文件作为新版本交付。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 恢复后核对输出目录 | 发现旧 minos 13.0 |
| 2026-09-26 | 完整重新构建并核对 | minos / plist 14.0，签名有效 |

<a id="nst-024"></a>

### NST-024 · 深色模式结果预览间歇性显示为白块

- **发现 / 更新日期**：2026-09-25 / 2026-09-26。
- **状态 / 来源**：已规避；离屏图与真实窗口截图均观察到。
- **环境与影响**：Intel、macOS 26.7，SwiftUI Image(nsImage:)；50 × 25 JPG 结果的 PNG 缩略图，浅色正常，深色结果只显示白矩形，原图仍正常。
- **现象与复现**：批量测试完成后依次渲染图片工具浅色、深色窗口；2026-09-26 实际窗口截图确认白块，不能继续归因于离屏截图。
- **定位证据与假设**：输出编码和浅色预览正常，异常出现在显示路径。添加 renderingMode(.original) 后恢复；撤回此修改后两次运行也通过，故“模板着色导致”仅是假设，不能视为已确认根因。没有得到稳定的旧实现红绿失败测试。
- **规避指南**：移除 NSImage 的表示选择路径，使用 ImageIO 立即解码受限缩略图为 CGImage，SwiftUI 明确按原图像素绘制；增加浅深色结果区域蓝色像素断言。单张预览仍限定 1000 像素。
- **验证**：修正后 `swift run ToolboxUITests --render --capture` 检查原图与结果的真实窗口；像素断言与最后运行结果见 [验证记录](../superpowers/validation/2026-09-26-image-tools.md)。最初单纯添加原色修饰后截图正常，但不将相关性当作根因证明。
- **关联**：[ImagePreviewView.swift](../../Sources/ToolboxUI/ImagePreviewView.swift)、[ImageBatchTests.swift](../../Sources/ToolboxUITests/ImageBatchTests.swift)、[NST-017](#nst-017)。规避提交：`e8a8b7a`。
- **下一步**：保留像素回归及真实窗口检查；如再次出现，保存实际缩略图与渲染状态，继续定位系统图像表示/绘制行为。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-25 | 深色离屏结果缺少图片像素 | 尚不能排除截图限制 |
| 2026-09-26 | 真实窗口截图同样为白块 | 确认显示路径异常 |
| 2026-09-26 | 原色修饰恢复；撤回后两次也通过 | 根因假设未证实，保留历史 |
| 2026-09-26 | 改用立即解码 CGImage 与原色显示，增加像素断言 | 当前路径通过，已规避 |

<a id="nst-025"></a>

### NST-025 · 推送 GitHub 时本机代理端口不可连接

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：待定位；实际 Git 推送错误。
- **环境与影响**：macOS、Git HTTPS remote；当前功能分支已提交，首次推送远程失败。
- **现象与复现**：执行 `git push -u origin codex/macos-developer-toolbox`，退出 128：`Failed to connect to 127.0.0.1 port 7897 after 0 ms: Couldn't connect to server`。
- **定位与根因**：Git 用户级配置含 `http.https://github.com.proxy=http://127.0.0.1:7897`，该端口连接被拒绝。清除环境代理并仅覆盖通用 `http.proxy` 仍失败，因为 URL 专用配置仍生效；不能据此断言 GitHub 直连不可用。
- **修复 / 尝试指南**：不修改全局配置，仅对当前命令清除环境代理，并覆盖 GitHub 专用代理：

~~~sh
env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy \
  git -c http.https://github.com.proxy= -c http.proxy= push -u origin codex/macos-developer-toolbox
~~~

- **验证**：普通推送和仅覆盖通用代理均退出 128；URL 专用覆盖后推送持续无响应；独立 `curl --noproxy '*' --head --connect-timeout 10 --max-time 20 --silent --show-error https://github.com` 退出 28，报 GitHub 443 连接 10006 ms 后超时。随后主动终止本次挂起的 Git 推送；未获得远程更新成功证据。`git diff --check` 通过；仅文档修改，产品测试未执行。
- **关联**：本条问题记录；待推送版本包含 `e8a8b7a` 与 `d330e77`，不修改应用代码。
- **下一步**：核对实际推送退出码和远程 HEAD；若直连仍失败，恢复可用网络或启动已配置代理后重试，不强制推送。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 普通推送及仅覆盖通用代理 | 均连接 127.0.0.1:7897 失败 |
| 2026-09-26 | 确认 GitHub URL 专用代理，按 URL 覆盖重试 | 推送无响应，独立 HTTPS 直连超时；终止挂起推送，待网络恢复 |
