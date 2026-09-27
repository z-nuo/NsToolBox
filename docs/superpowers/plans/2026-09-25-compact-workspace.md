# 紧凑工作区实施计划

> 执行方式：使用 superpowers:subagent-driven-development，编辑器子任务独立执行，其余按顺序实现并验证。

**目标：** 落实已批准的分类导航、顶部工具标签和紧凑双栏工作区。

**架构：** 复用 JSONToolModel、EncodingToolModel 与核心服务；SwiftUI 负责工作区布局，AppKit 编辑器提供行号、当前行和文本编辑。工具状态由根视图持有，切换保留输入。

**技术：** SwiftUI、AppKit、SwiftPM；macOS 13+，Universal 2，无新依赖。

**规格：** [已批准规划](../specs/2026-09-25-compact-workspace-design.md)。用户已于本任务明确批准实现。

## 任务 1：编辑器行号与编辑保护

文件：Sources/ToolboxUI/CodeEditor.swift；可新增 EditorTextView.swift；Sources/ToolboxUITests/EditorTests.swift。

- [x] 测试空文本、CRLF、Unicode、尾部换行的实际行号，以及选区与撤销。
- [x] 使用 NSRulerView 显示真实行号；当前行绘制不修改 NSTextStorage；保持长行横向滚动、IME 与语法色。
- [x] 通过 swift run ToolboxUITests 验证，真实窗口检查滚动和明暗适配。

接口：CodeEditor 原有绑定和 EditorSelection 不变；编辑器自包含行号与当前行处理。

## 任务 2：分类导航与共享工作区

文件：ToolboxRootView.swift、SharedViews.swift、WorkspaceStyle.swift、StateTests.swift。

- [x] 把原侧栏三工具改为一个开发工具分类，顶部按钮负责 ToolRoute 切换。
- [x] 提供紧凑面板标题、明确归属的复制/清空、HSplitView、底部状态摘要与完整错误弹出层。
- [x] 原生交互测试点击顶部按钮并验证 JSON → Base64 → URL → JSON 输入保留；最小尺寸检查。

接口：EditorPane 保留 title/text/highlights/error/selection，新增可编辑面板的清空按钮；WorkspaceStatus 接受 message/isError/isProcessing/counts，WorkspaceToolbar 容纳页面操作。

## 任务 3：工具页面

文件：JSONToolView.swift、EncodingToolView.swift、StateTests.swift。

- [x] JSON 四模式复用一组双栏；校验右侧显示报告并提供错误定位；格式化与压缩输出只读。
- [x] 对比差异面板默认折叠；展开显示差异路径，点击路径更新 EditorSelection。
- [x] 两种编码工具统一布局，保留自动计算和方向切换语义。
- [x] 验证局部清空不清掉另一侧、模式切换保留对比文本、无效输入不显示旧结果、校验定位、格式化两侧后撤销。

实现要点：只读输出使用 .constant(model.outputText)；局部清空通过对应输入 Binding 写空串；错误定位使用 JSONParseError.offset 的 UTF-16 范围；当前差异与错误来自现有模型。

## 任务 4：交付验证与记录

- [x] swift run ToolboxCoreTests；swift run ToolboxUITests；swift run ToolboxUITests --render。
- [x] 检查默认/最小窗口、浅色/深色预览和原生控件交互；如无完整人工验证，如实保留限制。
- [x] ./scripts/build-app.sh；验证双架构、最低系统版本与签名。
- [x] 更新 NST-014、新遇问题、README 与验证记录；git diff --check 并提交。

验收边界：未经真实用户窗口确认，不将布局偏差或历史图标问题标记为最终已解决。

## 执行结果

代码与原生交互验证完成；行号尺越界绘制问题已复现、修复并补像素测试。测试、构建与人工验收边界见 [验证记录](../validation/2026-09-25-compact-workspace.md)。分类栏沿用原生分栏宽度分配，本机初始为 200 pt，处于规定 120–200 pt 范围内，仍可拖动；不强制覆盖用户调整。
