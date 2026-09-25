# 紧凑工作区验证记录

日期：2026-09-25。环境：Intel Mac、macOS 26.7、Swift 6.3.3、默认 macOS 26.5 SDK；部署目标仍为 macOS 13.0。

## 已实现

- 左侧仅列工具集「开发工具」；主工作区顶部横向 JSON / Base64 / URL 标签。
- 紧凑操作栏、直边双栏、面板内复制与清空、统一底部状态；分类栏宽度限制 120–200 pt（原生分栏在本机初始分配为 200 pt），可拖动；编辑栏可调整宽度。
- JSON 校验右栏显示报告并支持错误定位；对比差异列表默认折叠，按路径定位。
- 编辑器真实行号、当前行提示、19 pt 行高、13 pt 等宽字体；跟随系统明暗。

## 实际执行

- `swift run ToolboxUITests`：状态切换、防抖、错误恢复、Unicode / CRLF 行号、滚动对齐、语法色、撤销与组合态通过。
- `swift run ToolboxUITests --render --capture`：退出码 0。完整 AppKit 事件循环运行，向测试窗口发送点击事件，验证顶部工具切换、三工具输入输出与输入保留、模式名称同步、只读结果、差异折叠、单侧清空与撤销、格式化两侧与撤销、校验错误定位。
- 新增行号绘制像素回归：尺外标记像素不被超大 dirty rect 覆盖，尺内确实绘制，调用后图形上下文 clip 恢复。
- 已查看窗口自身截图：JSON 对比、Base64 编码、校验报告、默认窗口、980 × 640 最小窗口深色外观；文本、标题、操作按钮和状态均可见。截图在 `build/previews/*-window.png`。
- 独立代码复审发现并修复编辑器辅助功能名称未同步问题；修复后复审未发现新的重要缺陷。

## 构建

- `swift run ToolboxCoreTests`：11 组通过，退出码 0。
- `./scripts/build-app.sh`：arm64 / x86_64 Release 编译、合并与本地签名完成，退出码 0；产物 `build/NsToolBox.app`。
- `xcrun vtool -show-build`：两个架构均为 minos 13.0。
- `codesign --verify --deep --strict --verbose=2 build/NsToolBox.app`：valid on disk，满足 Designated Requirement。
- `git diff --check`：通过。

## 验证边界

- 输入法测试模拟 marked text，未覆盖真实第三方输入法完整交互；没有人工完成 VoiceOver 朗读验收。
- NSHostingView 的 SwiftUI AX 子树在当前测试宿主中不完整；导航改用自身窗口 NSEvent 点击，编辑器仍验证原生辅助功能标签。
- `cacheDisplay` 离屏图不能作为完整视觉验收；`--capture` 仅截取测试进程自身窗口，需图形会话。其他应用窗口截图失败未用于结论。
- 未在 Apple Silicon 或 macOS 13 实机运行，未执行完整 Xcode 构建。
- NST-014 待用户确认新版实际布局；NST-001 图标显示问题没有新增用户确认，不关闭。

相关：[实施计划](../plans/2026-09-25-compact-workspace.md)、[问题指南](../../development/TROUBLESHOOTING.md)。
