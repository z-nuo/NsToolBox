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
| [NST-025](#nst-025) | Git 远程 | 推送 GitHub 时本机代理端口不可连接 | 已解决 |
| [NST-026](#nst-026) | 图片工作流 | 格式转换继承抠图参数并误报无人像 | 待验证 |
| [NST-027](#nst-027) | PNG / 交互 | 转成 PNG 后白色背景仍存在 | 待验证 |
| [NST-028](#nst-028) | 抠图 | Vision 无法分离白底文字素材 | 已规避 |
| [NST-029](#nst-029) | 诊断环境 | Python 缺少 PIL，无法读取图像通道 | 已规避 |
| [NST-030](#nst-030) | 开发脚本 | 技能脚本直接运行 permission denied | 已规避 |
| [NST-031](#nst-031) | 测试入口 | 多文件 main.swift 与 @main 冲突 | 已解决 |
| [NST-032](#nst-032) | 文本对比 | 首次上一处差异定位错误 | 已解决 |
| [NST-033](#nst-033) | 文本哈希 | 大输入未设资源上限 | 已解决 |
| [NST-034](#nst-034) | 图片信息 | 16 位 Alpha 被舍入为完全不透明 | 已解决 |
| [NST-035](#nst-035) | 重命名日志 | 执行与撤销日志 ID 重复 | 已解决 |
| [NST-036](#nst-036) | 重命名撤销 | 改名后结果身份未与原文件复核 | 已解决 |
| [NST-037](#nst-037) | 重命名序号 | 大序号截断或溢出静默省略 | 已解决 |
| [NST-038](#nst-038) | 重命名列表 | 执行成功后仍显示旧文件路径 | 已解决 |
| [NST-039](#nst-039) | 时间戳界面 | 复制按钮文字显示省略号 | 已解决 |
| [NST-040](#nst-040) | 重命名撤销 | 撤销链刷新指纹可能掩盖外部编辑 | 已解决 |
| [NST-041](#nst-041) | 图片编辑 | 编辑输出未复用单边上限 | 已解决 |
| [NST-042](#nst-042) | 图片信息界面 | 读取完成仍显示待处理 | 已解决 |
| [NST-043](#nst-043) | 原生交互测试 | 图片工具切换等待超时 | 已规避 |

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
- **关联**：[Package.swift](../../Package.swift)、[核心测试](../../Sources/ToolboxCoreTests/Runner.swift)、[UI 测试](../../Sources/ToolboxUITests/StateTests.swift)；cf08300、ed3319e。
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
- **关联**：[TextCodec.swift](../../Sources/ToolboxCore/TextCodec.swift)、[核心测试](../../Sources/ToolboxCoreTests/Runner.swift)；cf08300。
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
- **关联**：[JSONValue.swift](../../Sources/ToolboxCore/JSONValue.swift)、[JSONWriter.swift](../../Sources/ToolboxCore/JSONWriter.swift)、[核心测试](../../Sources/ToolboxCoreTests/Runner.swift)；cf08300、31b7b21。
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

- **2026-09-26 复发**：第一批扩展并行编写源文件时，SwiftPM 报 `input file modified during build`，以及根视图引用尚未落盘类型的中间态错误；修改完成后重跑编译通过。主任务统一运行最终构建，不把并行中间状态当作最终验证结果。

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
- **关联**：[JSONParser.swift](../../Sources/ToolboxCore/JSONParser.swift)、[核心测试](../../Sources/ToolboxCoreTests/Runner.swift)、[JSONToolModel.swift](../../Sources/ToolboxUI/JSONToolModel.swift)、[JSONToolView.swift](../../Sources/ToolboxUI/JSONToolView.swift)；cf08300、ed3319e。
- **防复发**：从首个真实类型错误排查，不关闭并发检查来规避线程安全。

- **2026-09-26 复发**：新增测试中 `&&` 右侧与 `precondition` 自动闭包直接包含 throwing 文件读取，分别报 `operator can throw but expression is not marked with try` 和 throwing autoclosure 错误；先读取为局部常量再断言后测试通过。图片信息视图 `.frame` 参数组合报 `extra argument width in call`，拆分合法修饰器后编译通过。预览测试访问重命名规则旧接口报 `has no member prefix/numberingEnabled`，同步为 `model.options` 后通过；未为测试保留冗余兼容属性。

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

- **发现 / 更新日期**：2026-09-25 / 2026-09-26。
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

- **2026-09-26 需求补充**：用户要求默认打开图片处理，AppModel 初始工具集改为 images，启动及新建窗口均生效。原生交互测试先确认初始页面，再主动切到开发工具验证原流程；`swift run ToolboxUITests --render --capture` 退出 0，实际窗口截图确认图片处理高亮且抠图工作区显示。此次属于默认入口偏好调整，不新增故障编号，整体布局验收状态保持待验证。

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

- **发现 / 更新日期**：2026-09-25 / 2026-09-26。
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

- **2026-09-26 第一批扩展再次复发**：`swift run ToolboxUITests --render --capture` 行为断言退出 0，但本次窗口截图子进程均退出 1，报 `could not create image from window`。原因仍未确认，重新打开为待定位；保留 NSView 位图与原生点击验证，不能将离屏位图当作真实窗口截图。

- **本轮最终恢复验证**：相同 `--render --capture` 命令最终退出 0，15 张真实窗口截图全部退出 0。已目视新增工具页面，当前路径恢复，状态改为已规避；恢复原因仍未确认，不归因于权限或锁屏。

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
- **状态 / 来源**：已解决；实际 Git 推送错误。
- **环境与影响**：macOS、Git HTTPS remote；当前功能分支已提交，首次推送远程失败。
- **现象与复现**：执行 `git push -u origin codex/macos-developer-toolbox`，退出 128：`Failed to connect to 127.0.0.1 port 7897 after 0 ms: Couldn't connect to server`。
- **定位与根因**：Git 用户级配置含 `http.https://github.com.proxy=http://127.0.0.1:7897`，该端口连接被拒绝。清除环境代理并仅覆盖通用 `http.proxy` 仍失败，因为 URL 专用配置仍生效；不能据此断言 GitHub 直连不可用。
- **修复 / 尝试指南**：优先恢复既有代理或网络后运行普通推送。本次重试未修改配置，原命令已成功；具体外部恢复操作未确认。以下绕过代理命令曾尝试，但当时直连也超时，不是本次成功路径：

~~~sh
env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u http_proxy -u https_proxy -u all_proxy \
  git -c http.https://github.com.proxy= -c http.proxy= push -u origin codex/macos-developer-toolbox
~~~

- **验证**：普通推送和仅覆盖通用代理均退出 128；URL 专用覆盖后推送持续无响应；独立 `curl --noproxy '*' --head --connect-timeout 10 --max-time 20 --silent --show-error https://github.com` 退出 28，报 GitHub 443 连接 10006 ms 后超时。随后主动终止本次挂起的 Git 推送；未获得远程更新成功证据。`git diff --check` 通过；仅文档修改，产品测试未执行。
- **关联**：本条问题记录；待推送版本包含 `e8a8b7a` 与 `d330e77`，不修改应用代码。
- **恢复验证**：用户要求重试后，`git push -u origin codex/macos-developer-toolbox` 退出 0，远程创建同名分支并建立上游跟踪；原有提交包括 `8feacef` 已推送。未修改全局代理配置。
- **下一步 / 防复发**：再次遇到相同错误先检查既有代理服务；每次推送核对退出码和上游状态，不强制推送。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 普通推送及仅覆盖通用代理 | 均连接 127.0.0.1:7897 失败 |
| 2026-09-26 | 确认 GitHub URL 专用代理，按 URL 覆盖重试 | 推送无响应，独立 HTTPS 直连超时；终止挂起推送，待网络恢复 |
| 2026-09-26 | 用户要求重新推送，直接执行原命令 | 退出 0，远程分支创建成功；状态改为已解决 |

<a id="nst-026"></a>

### NST-026 · 图片工具共用流程导致格式转换误报无人像

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：待验证；用户实际体验反馈。
- **环境与影响**：当前 macOS 图片工具集；先人像抠图失败，再添加图片用于格式转换，转换继续报无人像。
- **现象与复现**：选择人像抠图处理无人物图，切换格式转换、添加第二张无人物图并开始处理；结果仍尝试人像分割。用户将顶部标签理解为独立工具，而当前实现是共享处理步骤。
- **定位与根因**：ImageBatchModel 共用 options / items / results，selectedTool 只影响界面，processAll 总是传入全部 options。旧设计明确组合流程，交互预期与实现不一致。
- **修复指南**：各工具独立会话、参数和结果；仅执行当前操作，按钮使用明确动作；需要连续处理时显式传递选中结果，目标工具导入独立快照。
- **验证**：新增实际 Vision / 文件处理复现用例，修正前失败；最初使用蓝色矩形作为无人像样本却被算法识别为人物，测试报 `Fixture must fail person extraction`；不能稳定复现，改用纯白图。旧版本 `swift run ToolboxUITests --image-isolation-only` 退出 1，错误为 `Format conversion must not run prior person extraction: 未检测到人像，请尝试更清晰的人像图片。`；修正后同命令退出 0。完整 `swift run ToolboxUITests --render --capture` 退出 0，包含真实窗口标签切换、独立结果与手动传递快照检查，7 个截图均成功，浅深色预览像素正常。原图无人物的提示保留，不以隐藏错误规避问题。
- **关联**：[图片模型](../../Sources/ToolboxUI/ImageBatchModel.swift)、[图片页面](../../Sources/ToolboxUI/ImageToolView.swift)、[回归测试](../../Sources/ToolboxUITests/ImageOperationTests.swift)。代码提交：`ced56a4`。
- **下一步**：技术回归已通过，等待用户对新交互的实际体验验收；真实系统文件选择面板和跨设备矩阵未在本轮人工验收。详见 [验证记录](../superpowers/validation/2026-09-26-independent-image-tools.md)。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 用户反馈跨工具误报无人像 | 确认共享流程设计与预期不符 |
| 2026-09-26 | 新增复现测试 | 蓝矩形会被 Vision 判为人物，改用纯白样本复现 |
| 2026-09-26 | 独立工具与原生切换回归通过，检查浅深色真实窗口 | 待验证；用户体验待确认 |

<a id="nst-027"></a>

### NST-027 · 转换 PNG 后原白色背景仍然存在

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：待验证；用户反馈，已确认使用“格式转换 → PNG”。
- **环境与影响**：本地有效 RGB PNG，没有 alpha 通道；用户期望转换格式同时获得透明底。
- **现象与复现**：将带白色背景的 RGB 图片输出为 PNG，画面仍为白底；用户认为图片不是有效 PNG。
- **定位与根因**：PNG 支持但不强制透明。ImageIO / file / sips 均确认输入合法、无 alpha；原色白底是像素内容。格式转换保留背景符合独立工具行为，原提示“PNG 保留透明度”未充分说明不会自动去底。
- **修复指南**：格式转换页明确说明“不会自动去底”，指引用户进入抠图。白底文字可用新增去白底模式；人物照片用人像抠图。保持工具独立，不在转换时偷偷执行分割。
- **验证**：本地样本转换后 alpha 均为 255；去白底后输出包含完全透明、半透明和不透明像素，角落 alpha 为 0。原文件未修改。图片测试 10/10 通过；UI 原生工作流与像素检查通过。素材及文字内容不写入版本控制。
- **关联**：[ImageToolView.swift](../../Sources/ToolboxUI/ImageToolView.swift)、[NST-028](#nst-028)、[NST-026](#nst-026)。
- **下一步**：用户实际体验新说明与去白底入口；格式转换的背景保留行为继续保持。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 用户反馈新工具输出 PNG 仍有白底 | 待定位 |
| 2026-09-26 | 用户确认使用格式转换；检查输入无 alpha | 确认是预期差异，完善操作提示 |
| 2026-09-26 | 新增去白底并验证透明输出 | 待验证；新交互待用户体验 |

<a id="nst-028"></a>

### NST-028 · 自动主体分割无法处理部分白底文字素材

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：已规避；使用用户反馈的本地素材实际运行系统 API。
- **环境与影响**：Intel、macOS 26.7；白底彩色文字素材。Vision 通用主体与人像分割都无法满足此类去底需求。
- **现象与复现**：通用模式报“未检测到可分离的主体”，人像模式报“未检测到人像”。不能让用户仅切换到自动去背景后就宣称该素材问题解决。
- **定位与根因**：系统语义分割未识别出主体；文字素材没有人物，不能用人像算法替代。原应用缺少按背景颜色清除的路径。
- **规避指南**：新增独立“去白底”模式，容差 0%～30%、默认 5%，按 sRGB 到白色的距离设置 alpha，并为近白色提供软过渡；减少 alpha 时同步去除白色混合成分，保留原透明度。保留现有 Vision 模式且改进失败指引，不将颜色去底伪装成语义识别。
- **边界**：主体中的白色也会被去除，容差过大可能损伤浅色描边；复杂阴影仍可能保留浅边。实测深色衬底预览存在浅边，未声称达到精细遮罩质量。当前像素处理仍为 8 位 sRGB。
- **验证**：`swift run ToolboxImageTests` 先在占位路径失败（白底仍不透明，9/10），实现后 10/10 通过；覆盖白底、近白、黄色描边、彩色主体、软边还原、已有半透明和非法容差。`swift run ToolboxUITests --render --capture` 退出 0，包含界面容差传递与真实透明输出、8 个窗口截图。提供样本另行本地探测，`sips -g hasAlpha` 输出 yes，目视深色合成预览确认大面积背景已清除，未修改原图。
- **关联**：[ImageProcessor.swift](../../Sources/ToolboxImages/ImageProcessor.swift)、[ImageTypes.swift](../../Sources/ToolboxImages/ImageTypes.swift)、[图片测试](../../Sources/ToolboxImageTests/main.swift)、[UI 回归](../../Sources/ToolboxUITests/ImageOperationTests.swift)。
- **构建复核**：`./scripts/build-app.sh` 退出 0；`lipo -archs` 确认为 x86_64 / arm64，`vtool -show-build` 两架构最低版本均为 14.0；`codesign --verify --deep --strict` 退出 0。详见 [本轮验证记录](../superpowers/validation/2026-09-26-white-background.md)。
- **下一步**：继续保留 Vision 对此样本不可用的能力边界；复杂白色主体、渐变背景和精细边缘另行评估，用户素材不纳入测试仓库。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 原生通用 / 人像算法处理本地文字素材 | 均无可用主体 |
| 2026-09-26 | 添加去白底测试，先运行未实现路径 | 白底 alpha 断言失败 |
| 2026-09-26 | 颜色去底实现、核心及界面验证 | 真实透明输出通过；复杂边缘限制保留，已规避 |

<a id="nst-029"></a>

### NST-029 · 诊断用 Python 环境未安装 Pillow

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：已规避；实际诊断命令失败。
- **环境与影响**：系统 python3，尝试 `from PIL import Image` 检查 alpha；应用运行不依赖 Python。
- **现象与复现**：导入时报 `ModuleNotFoundError: No module named 'PIL'`，命令退出 1。
- **定位与根因**：当前 Python 环境没有 Pillow 包；不是图片损坏或应用编码错误。
- **规避指南**：不修改全局 Python 环境。使用系统 `file`、`sips -g hasAlpha` 与现有 Swift ImageIO / CoreGraphics 探针读取像素和通道。
- **验证**：原生探针成功输出 alpha 分类统计，sips 返回 hasAlpha 检查结果；PNG 原图与处理结果已可对比。Pillow 安装未执行，因为不需要引入额外依赖。
- **关联**：[NST-027](#nst-027)、[NST-028](#nst-028)；临时探针在被忽略的 build 目录，无产品代码变更。
- **下一步**：后续诊断优先使用已安装的原生图片工具；不要将可选诊断依赖作为产品依赖。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 导入 PIL | 模块不存在 |
| 2026-09-26 | 改用原生通道与像素探针 | 检查通过，已规避 |

<a id="nst-030"></a>

### NST-030 · 技能辅助脚本缺少可执行权限

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：已规避；第一批扩展的计划工作目录初始化命令失败。
- **环境与影响**：本机 zsh；开发辅助脚本，不影响应用。
- **现象与复现**：直接运行 subagent-driven-development 的 `scripts/sdd-workspace` 返回 `permission denied`，退出 126。
- **定位与根因**：脚本首行为 bash shebang，直接执行被权限拒绝；无需修改产品或插件文件权限。
- **修复指南**：通过 `bash <技能目录>/scripts/sdd-workspace docs/superpowers/plans/2026-09-26-toolbox-phase-one.md` 显式解释执行。
- **验证**：上述 bash 命令退出 0，返回当前计划独立工作目录。
- **关联**：[第一批计划](../superpowers/plans/2026-09-26-toolbox-phase-one.md)；无产品代码修改。
- **下一步**：同类脚本先检查 shebang，避免为运行脚本改变插件权限。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 直接运行后改用 bash | 退出 126 后退出 0，已规避 |

<a id="nst-031"></a>

### NST-031 · 核心测试拆分文件后入口冲突

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：已解决；新增功能测试时实际编译失败。
- **环境与影响**：SwiftPM ToolboxCoreTests 可执行目标，原先只有带 @main 的 main.swift。
- **现象与复现**：增加 UtilityTests.swift 后运行 `swift build --target ToolboxCoreTests`，报 `@main attribute cannot be used in a module that contains top-level code`。
- **定位与根因**：多文件目标中 main.swift 被编译器作为顶层入口，与 @main 入口声明冲突。
- **修复指南**：将 main.swift 改名为 Runner.swift，保留 @main CoreTestRunner；各测试通过扩展添加并从 Runner 调用。
- **验证**：改名后 `swift run ToolboxCoreTests` 退出 0，原 11 组和第一批新增逻辑通过；初始编译同时出现新 API 尚未定义的预期测试先行错误。
- **关联**：[测试入口](../../Sources/ToolboxCoreTests/Runner.swift)、[第一批计划](../superpowers/plans/2026-09-26-toolbox-phase-one.md)。
- **下一步**：保持 Runner.swift 入口，新增测试通过扩展并显式接入。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 新增多文件功能测试后编译 | 入口冲突，重命名为 Runner.swift，测试通过 |

<a id="nst-032"></a>

### NST-032 · 首次上一处差异定位错误

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：已解决；代码审查发现，非用户故障。
- **环境与影响**：本机 Intel、macOS 26.7、Swift 6.3.3；第一批文本对比。
- **现象与复现**：有两处及以上差异时首次点击上一处会定位倒数第二处。
- **定位与根因**：初始索引 -1 与模运算组合导致偏移。
- **修复指南**：将导航索引置于模型，首次上一处直接选择最后一处。
- **验证**：`swift run ToolboxUITests` 退出 0，覆盖首次前后导航和输入变化清除范围。
- **关联**：[TextCompareView.swift](../../Sources/ToolboxUI/TextCompareView.swift)、[第一批计划](../superpowers/plans/2026-09-26-toolbox-phase-one.md)；本轮提交交付时关联验证报告。
- **下一步**：保持导航边界回归。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 发现、定位并实施修正 | 已解决；验证边界如上 |

<a id="nst-033"></a>

### NST-033 · 大输入未设资源上限

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：已解决；代码审查风险预防，未观察到用户卡死。
- **环境与影响**：本机 Intel、macOS 26.7、Swift 6.3.3；第一批文本哈希。
- **现象与复现**：旧实现对任意长度文本在主线程同步计算摘要。
- **定位与根因**：未限制输入量，大规模粘贴可能增加主线程耗时。
- **修复指南**：限制每次输入为 2 MiB UTF-8，超限清空结果并显示错误。
- **验证**：`swift run ToolboxUITests` 退出 0，验证超限输入清空旧摘要；固定向量录入缺失也已校正。
- **关联**：[DeveloperUtilityViews.swift](../../Sources/ToolboxUI/DeveloperUtilityViews.swift)、[第一批计划](../superpowers/plans/2026-09-26-toolbox-phase-one.md)；本轮提交交付时关联验证报告。
- **下一步**：维持明确上限；超大文件摘要另行设计流式读取。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 发现、定位并实施修正 | 已解决；验证边界如上 |

<a id="nst-034"></a>

### NST-034 · 16 位 Alpha 被舍入为完全不透明

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：已解决；独立审查与本地合成探针实测。
- **环境与影响**：本机 Intel、macOS 26.7、Swift 6.3.3；第一批图片信息。
- **现象与复现**：生成 1×1、16 位 PNG，alpha=65534；原始通道为 FE FF，inspect 却返回 opaqueAlphaChannel。
- **定位与根因**：检查透明度先转为 8 位像素，极浅透明舍入 255。
- **修复指南**：按保留源 Alpha 精度的栅格检查，加入 65534 与 65535 边界测试。
- **验证**：真实 16 位 PNG 回归先失败后通过；`swift run ToolboxImageTests` 14/14 组通过、退出 0。独立复审探针确认 alpha=65534 已分类为透明。扫描采用 2048×128 的 16 位分块，每块缓冲区最多 2 MiB；系统解码器另占内存，未实测峰值。
- **关联**：[ImageProcessor.swift](../../Sources/ToolboxImages/ImageProcessor.swift)、[第一批计划](../superpowers/plans/2026-09-26-toolbox-phase-one.md)；本轮提交交付时关联验证报告。
- **下一步**：保留原精度 alpha 检测；8 位源仍使用完整 RGBA 缓冲区。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 发现、定位并实施修正 | 已解决；验证边界如上 |

<a id="nst-035"></a>

### NST-035 · 执行与撤销日志 ID 重复

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：已解决；独立代码审查与探针实测。
- **环境与影响**：本机 Intel、macOS 26.7、Swift 6.3.3；第一批重命名日志。
- **现象与复现**：两次执行、两次撤销产生 4 条日志却只有 2 个唯一 id，违反 SwiftUI ForEach 身份要求。
- **定位与根因**：日志条目身份与操作关联身份混用。
- **修复指南**：每条日志生成独立 UUID，使用 operationID 关联执行和撤销。
- **验证**：`swift run ToolboxUITests` 退出 0，覆盖执行及撤销日志 ID 唯一性、TSV 导出。
- **关联**：[BatchRename.swift](../../Sources/ToolboxCore/BatchRename.swift)、[第一批计划](../superpowers/plans/2026-09-26-toolbox-phase-one.md)；本轮提交交付时关联验证报告。
- **下一步**：后续重试必须新增日志身份而不是复用旧条目。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 发现、定位并实施修正 | 已解决；验证边界如上 |

<a id="nst-036"></a>

### NST-036 · 改名后结果身份未与原文件复核

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：已解决；代码审查风险预防，未观察到真实文件损坏。
- **环境与影响**：本机 Intel、macOS 26.7、Swift 6.3.3；第一批重命名撤销。
- **现象与复现**：改名后只要目标指纹非空就允许撤销；并发替换可能令记录关联错误文件。
- **定位与根因**：执行后没有把目标的设备号、inode、大小、mtime 与原文件身份比较。
- **修复指南**：执行后比较原身份；不匹配则记录改名成功但取消撤销资格。执行与撤销前仍重验，目标使用 RENAME_EXCL。
- **验证**：`swift run ToolboxCoreTests` 退出 0，含外部修改/替换和拒绝覆盖测试；恶意精确竞态未执行。
- **关联**：[BatchRename.swift](../../Sources/ToolboxCore/BatchRename.swift)、[第一批计划](../superpowers/plans/2026-09-26-toolbox-phase-one.md)；本轮提交交付时关联验证报告。
- **下一步**：POSIX 路径核对和改名无法保证同一个源身份原子操作；明确首版限制。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 发现、定位并实施修正 | 已解决；验证边界如上 |

<a id="nst-037"></a>

### NST-037 · 大序号截断或溢出静默省略

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：已解决；代码审查发现并补回归。
- **环境与影响**：本机 Intel、macOS 26.7、Swift 6.3.3；第一批重命名序号。
- **现象与复现**：公共选项传入超过 Int32 的序号，旧 `%d` 格式可能截断；Int 溢出时旧路径输出空序号。
- **定位与根因**：Swift Int 经 C int 格式输出宽度不匹配，溢出缺少错误反馈。
- **修复指南**：改为 String(Int) 后补零；溢出或参数非法明确显示错误。
- **验证**：`swift run ToolboxCoreTests` 退出 0，含 Int.max、下一项溢出及补零测试。
- **关联**：[RenameTests.swift](../../Sources/ToolboxCoreTests/RenameTests.swift)、[第一批计划](../superpowers/plans/2026-09-26-toolbox-phase-one.md)；本轮提交交付时关联验证报告。
- **下一步**：保留大整数边界测试，即使 UI 当前限制起始值。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 发现、定位并实施修正 | 已解决；验证边界如上 |

<a id="nst-038"></a>

### NST-038 · 执行成功后仍显示旧文件路径

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：已解决；代码审查发现并补回归。
- **环境与影响**：本机 Intel、macOS 26.7、Swift 6.3.3；第一批重命名列表。
- **现象与复现**：成功改名后列表 URL 保留原名，刷新预览错误显示源文件不存在。
- **定位与根因**：结果日志正确，但列表未同步成功目标路径。
- **修复指南**：仅映射实际成功项至新路径，失败项保持原路径；撤销后相应恢复。
- **验证**：`swift run ToolboxUITests` 退出 0，覆盖两次执行、列表更新、清空后会话撤销。
- **关联**：[BatchRenameView.swift](../../Sources/ToolboxUI/BatchRenameView.swift)、[第一批计划](../superpowers/plans/2026-09-26-toolbox-phase-one.md)；本轮提交交付时关联验证报告。
- **下一步**：保持按 operationID 匹配实际结果，不能按成功项数量推断位置。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 发现、定位并实施修正 | 已解决；验证边界如上 |

<a id="nst-039"></a>

### NST-039 · 复制按钮文字显示省略号

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：已解决；本轮 NSView 渲染位图目视发现。
- **环境与影响**：本机 Intel、macOS 26.7、Swift 6.3.3；第一批时间戳界面。
- **现象与复现**：时间戳输出行复用 58 点宽复制按钮，默认字号下只显示图标与省略号。
- **定位与根因**：独立输出行缺少已有工具栏的小号控件环境。
- **修复指南**：仅为时间戳输出行复制按钮指定 12 点字体和 small controlSize。
- **验证**：`swift build --target ToolboxUI` 退出 0；修改后位图已目视确认“复制”文字完整；系统窗口截图仍失败，用户实际显示待确认，另见 NST-017。
- **关联**：[DeveloperUtilityViews.swift](../../Sources/ToolboxUI/DeveloperUtilityViews.swift)、[第一批计划](../superpowers/plans/2026-09-26-toolbox-phase-one.md)；本轮提交交付时关联验证报告。
- **下一步**：复核最小窗口可读性；不以构建通过代替视觉确认。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 发现、定位并实施修正 | 待验证；验证边界如上 |

- **最终显示确认**：真实 `timestamp-tool-window.png` 截图退出 0，两个输出行的“复制”文字均完整，状态改为已解决。

<a id="nst-040"></a>

### NST-040 · 撤销链刷新指纹可能掩盖外部编辑

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：已解决；主任务审查发现，非用户故障。
- **环境与影响**：本机 Intel、macOS 26.7、Swift 6.3.3；第一批重命名撤销。
- **现象与复现**：A 改为 B，外部编辑 B，再改为 C；撤销 C→B 后若只按 inode 刷新前序指纹，会让 A←B 接受外部修改内容。
- **定位与根因**：刷新前序身份仅比较 device/inode，未保留内容大小与修改时间约束。
- **修复指南**：前序指纹刷新必须同时匹配原 size/mtime，仅允许本应用重命名引起的 ctime 变化。
- **验证**：真实文件回归确认撤销结果为 [成功, 失败]：B 保留外部修改，A 未恢复，第一步仍可定位；`swift run ToolboxCoreTests` 退出 0。
- **关联**：[BatchRename.swift](../../Sources/ToolboxCore/BatchRename.swift)、[第一批计划](../superpowers/plans/2026-09-26-toolbox-phase-one.md)；本轮提交交付时关联验证报告。
- **下一步**：确认第二步可以退回 B，而第一步保留失败记录，不继续重命名已修改文件。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 发现、定位并实施修正 | 已解决；验证边界如上 |

<a id="nst-041"></a>

### NST-041 · 图片编辑输出未校验单边尺寸上限

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：已解决；审查发现后补测试复现。
- **环境与影响**：第一批新增独立图片编辑路径，Intel、macOS 26.7。
- **现象与复现**：16385×1 PNG 编辑路径未拒绝，回归报 `FAIL 编辑输出尺寸限制：应拒绝：16384`。
- **定位与根因**：新编辑路径有总像素上限，但遗漏原处理路径的输出单边 16384 限制。
- **修复指南**：根据裁剪与旋转确定输出宽高，完整像素解码前检查单边上限；裁剪边界使用减法检查，避免整数相加溢出。
- **验证**：同一测试先失败后通过，`swift run ToolboxImageTests` 14/14、退出 0。
- **关联**：[图片处理](../../Sources/ToolboxImages/ImageProcessor.swift)、[像素测试](../../Sources/ToolboxImageTests/main.swift)。
- **下一步**：所有新增输出路径保持相同资源约束。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 补边界测试并在解码前校验 | 已解决 |

<a id="nst-042"></a>

### NST-042 · 图片信息读取完成仍显示待处理状态

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：已解决；NSView 渲染位图目视发现。
- **环境与影响**：图片信息新入口；用户导入后已看到属性，但列表为待处理、底部为零结果，且没有处理按钮。
- **现象与复现**：导入 PNG 到图片信息，属性已读取完成；仍沿用处理类工具的状态文字，预览无棋盘格。
- **定位与根因**：检查类入口复用了处理类列表/底部状态文案，预览未复用透明底呈现。
- **修复指南**：成功项改为已读取、底部展示读取数；隐藏无用结果传递入口，使用现有棋盘格展示透明像素。
- **验证**：图片会话回归与 `--render --capture` 退出 0；真实 image-info-tool-window.png 确认“已读取”、读取数量、棋盘格正常且无结果传递入口。
- **关联**：[图片界面](../../Sources/ToolboxUI/ImageToolView.swift)、[信息预览](../../Sources/ToolboxUI/ImageInformationView.swift)。
- **下一步**：后续检查类工具继续使用检查状态，不复用处理结果文案。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 发现信息页状态与实际操作不符 | 真实窗口验证通过，已解决 |

<a id="nst-043"></a>

### NST-043 · 原生测试在图片工具切换时偶发等待超时

- **发现 / 更新日期**：2026-09-26 / 2026-09-26。
- **状态 / 来源**：已规避；本轮最终图形测试实际失败，非用户反馈。
- **环境与影响**：SwiftPM / NSHostingView 原生事件测试、Intel、macOS 26.7；该轮测试退出 132，后续打包因 && 未执行。
- **现象与复现**：图片处理刚结束后发送顶部标签点击，`ImageOperationTests.swift` 等待 selectedTool 报 `Fatal error: Timed out waiting for UI state`。
- **定位与假设**：同代码单独运行 `swift run ToolboxUITests --image-isolation-only --render` 退出 0，未稳定复现。假设是模型 isBusy 已完成、SwiftUI 按钮 disabled 状态尚未提交到视图；未证明为产品切换缺陷。
- **规避指南**：仅在测试发送点击前等待 100 ms 并 layoutSubtreeIfNeeded；保留真实 NSEvent 点击及原目标状态断言，不直接修改模型冒充点击成功，不跳过原测试。
- **验证**：最终 `swift run ToolboxUITests --render --capture` 退出 0，独立图片切换与全部原生工作流通过；15 张截图均退出 0。后续 `./scripts/build-app.sh` 退出 0。
- **关联**：[原生图片交互测试](../../Sources/ToolboxUITests/ImageOperationTests.swift)、[NST-017](#nst-017)。修复提交 `8c49fb9`。
- **下一步**：如再次复发记录具体路由、按钮可用性与窗口布局；当前计时规避不能证明间歇性根因已消除。

| 日期 | 操作或新证据 | 结果 |
| --- | --- | --- |
| 2026-09-26 | 完整图形测试一次超时，独立测试通过 | 假设为模型与视图更新时序差异 |
| 2026-09-26 | 点击前等待视图更新，保留真实断言 | 完整测试与打包通过，已规避 |

第一批扩展关联提交：核心 `5d316c7`、图片 `126fa65`、界面与原生工作流 `8c49fb9`。完整结果见 [第一批验证记录](../superpowers/validation/2026-09-26-toolbox-phase-one.md)。
