# 时间戳工具增强验证

日期：2026-09-26；Intel、macOS 26.7、Swift 6.3.3、SDK 26.5。设计与官网参考见 [增强计划](../plans/2026-09-26-timestamp.md)。问题状态统一维护在 [问题指南](../../development/TROUBLESHOOTING.md)，本轮涉及 NST-044–050 及 NST-017 复现记录。

| 检查 | 实际结果 |
| --- | --- |
| `swift run ToolboxCoreTests` | 退出 0；负毫秒、ISO 显式偏移、DST、批量错误隔离、行数/字节上限、时间差及两端本地年份范围回归通过 |
| `swift run ToolboxUITests --timestamp-only --render --capture` | 退出 0；原生输入、两侧错误隔离、模式保留、批量按钮与截图通过 |
| `swift run ToolboxUITests --render --capture` | 退出 0；完整状态、编辑器、图片/文件工作流、导航回归通过；17 张真实窗口截图均退出 0 |
| `./scripts/build-app.sh` | 退出 0；x86_64 + arm64 Universal 2，最低 macOS 14；脚本的 codesign 严格校验通过 |
| `git diff --check` | 退出 0 |

真实窗口重点验收：毫秒 .123 完整显示、上海 1900 年边界输入可转换、批量结果行首完整、逐行错误可定位、双栏布局和工具栏无挤压；时间差以天/时/分/秒/毫秒及总秒/毫秒展示。编辑器 tiling 修改后，行号、滚动、撤销、输入法、JSON 高亮和跨工具状态保留均通过完整回归。

应用产物：`build/NsToolBox.app`。截图：`build/previews/timestamp-{tool,batch,difference}-window.png`。临时日志和截图不提交；关键失败尝试、根因与修复步骤在问题指南中保留。当前只在 Intel 实机执行；Apple Silicon 进行了交叉编译和架构校验，未在 M 系列实机运行。本轮未重新验收 Finder / Dock 图标历史问题，不更改其状态。

代码复核重点：整数毫秒运算有日期范围约束；本地 1900 / 9999 年边界有时区往返回归；负数秒采用向下取整；日期按固定 Gregorian/POSIX 解析、拒绝 DST 歧义；批量后台处理有资源上限及修订号检查，旧结果不会覆盖新输入；未增加第三方依赖。
