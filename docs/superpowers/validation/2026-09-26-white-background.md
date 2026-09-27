# 去白底与 PNG 提示验证记录

日期：2026-09-26。环境：Intel、macOS 26.7、Swift 6.3.3、SDK 26.5。

当前问题状态统一见 [NST-027](../../development/TROUBLESHOOTING.md#nst-027)、[NST-028](../../development/TROUBLESHOOTING.md#nst-028)、[NST-029](../../development/TROUBLESHOOTING.md#nst-029)。

## 验证结果

| 命令 / 检查 | 实际结果 |
| --- | --- |
| `swift run ToolboxImageTests` | 10/10 组通过，退出 0；新增测试在未实现路径先失败，再通过 |
| `swift run ToolboxUITests --render --capture` | 退出 0；独立工具、参数传递、透明像素及原生工作流通过，8 个窗口截图成功 |
| `./scripts/build-app.sh` | 退出 0，生成 `build/NsToolBox.app` |
| `lipo -archs build/NsToolBox.app/Contents/MacOS/NsToolBox` | x86_64 arm64 |
| `vtool -show-build build/NsToolBox.app/Contents/MacOS/NsToolBox` | 两架构最低 macOS 14.0 |
| `codesign --verify --deep --strict build/NsToolBox.app` | 退出 0 |
| `git diff --check` | 退出 0 |

## 原始场景

用户确认使用“格式转换 → PNG”。输入为有效 RGB PNG，单纯转换后没有透明像素；转换格式不会自动移除白底。Vision 通用主体与人像模式均无法识别该文字素材。

新增“抠图 → 去白底”默认容差 5% 后，本地素材输出包含完全透明、半透明与不透明像素，角落 alpha 为 0；`sips -g hasAlpha` 为 yes。原图保持不变。已查看深色衬底合成预览，大面积白底和文字间隙已移除，但阴影周围仍有浅色边缘。提高容差可能损伤浅色主体，主体中的白色也会被移除。

已查看实际窗口截图，去白底模式、容差控件、左右预览和透明棋盘格正常。临时日志、素材与结果保存在被忽略的 build 目录，用户原始内容不纳入版本控制。

## 未执行与验收范围

- Apple Silicon 与 macOS 14 实机验证未执行；双架构构建不能替代实机验证。
- 用户对新入口及文案的实际体验待确认；系统文件选择和保存面板未新增人工验收。
- JSON / 编解码核心未修改，本轮未重复核心测试。
