# 图片处理工具集验证记录

日期：2026-09-25～2026-09-26。规格见 [图片处理设计](../specs/2026-09-25-image-tools-design.md)。实现提交：`e8a8b7a`；未推送远程。

## 环境与范围

Intel x86_64、macOS 26.7（25G229）、Swift 6.3.3、SDK 26.5。目标最低 macOS 14，构建 Universal 2。系统 Vision、ImageIO、CoreImage 原生本地处理，无第三方依赖。

## 实际命令与结果

| 日期 | 命令 / 检查 | 结果 |
| --- | --- | --- |
| 09-25 | `swift run ToolboxCoreTests` | 退出 0；11 组通过 |
| 09-25 | `swift run ToolboxImageTests --vision-person build/fixtures/astronaut.png` | 退出 0；10/10 组通过，其中 9 组默认离线运行、1 组显式本地人像样本 |
| 09-25 | `swift run ToolboxUITests` | 退出 0；图片批量和原开发工具状态测试通过 |
| 09-26 | `swift run ToolboxUITests --render --capture` | 最后退出 0；批量、实际退出缓存清理、原生事件交互、浅深色图片像素断言通过；7 个窗口截图均退出 0 |
| 09-26 | `./scripts/build-app.sh` | 退出 0；生成 `build/NsToolBox.app`，arm64 与 x86_64 Release |
| 09-26 | `lipo build/NsToolBox.app/Contents/MacOS/NsToolBox -archs` | x86_64 arm64 |
| 09-26 | `xcrun vtool -show-build build/NsToolBox.app/Contents/MacOS/NsToolBox` | 两架构 minos 14.0，SDK 26.5 |
| 09-26 | `plutil -extract LSMinimumSystemVersion raw build/NsToolBox.app/Contents/Info.plist` | 14.0 |
| 09-26 | `codesign --verify --deep --strict --verbose=2 build/NsToolBox.app` | 退出 0；本地 ad-hoc 签名有效 |
| 09-26 | `git diff --check` | 退出 0 |

截图、临时样本与日志位于被忽略的 `build`，关键结论保留在本文与问题指南。

## 核心与真实推理

生成测试图覆盖：PNG/JPG 识别、EXIF 旋转与镜像、比例与指定尺寸、PNG 透明度、JPG 底色与质量、非法参数/格式、有效超尺寸图拒绝。16 位 Display P3 PNG 在原尺寸、100% 和相同目标尺寸配置下保留原始字节与位深；实际像素变换按规格输出 8 位 sRGB。

当前 Intel 上实际执行两种 Vision 请求：

- 白图：通用主体、人像模式均明确报告无主体。
- 512 × 512 合成球体：通用模式保留中心（alpha > 200），角落透明（alpha < 20）。
- 512 × 512 真实人像：人物 alpha > 200 的像素为 108853，背景 alpha < 20 的像素为 138057，总计 262144。

人像为 scikit-image 的 NASA astronaut 样本，来源：<https://raw.githubusercontent.com/scikit-image/scikit-image/v0.19.3/skimage/data/astronaut.png>。样本仅保存在 `build/fixtures`，不是用户照片；默认测试不下载文件，额外人像探测需显式传入本地路径。该样本通过不能代表所有发丝、复杂背景或人物均有相同效果。

## 批量与界面

- 重复文件去重；无效输入单项失败，其他图片继续。
- 导入保留私有源快照与受限缩略图，列表不持有整批完整像素。
- 50% 输出 100 × 50、25% 输出 50 × 25；参数变更使旧结果失效。
- 取消后无残留 processing 状态，可以重新执行。
- 不存在目录的导出失败保留结果，可重试；连续导出命名不同，原图及第一次导出字节不变。
- 清空/删除清理缓存而不删除原图；真实 `NSApp.terminate` 子进程退出后，父进程检查其会话缓存目录已不存在。
- 开发工具 → 图片处理 → 开发工具的原生窗口事件通过，JSON 输入保留。
- 检查 780 × 640 图片工作区的浅深色真实窗口截图：列表、参数、原图/结果、底部尺寸及体积可见；最终两种外观的结果区域蓝色像素断言通过。

窗口截图曾失败、深色图片曾间歇性显示白块；均保留完整发现、尝试与边界，不能将末次成功抹去历史。当前状态分别见 [NST-017](../../development/TROUBLESHOOTING.md#nst-017) 和 [NST-024](../../development/TROUBLESHOOTING.md#nst-024)。

## 未执行与边界

Apple Silicon、macOS 14 实机、完整 Xcode 构建、真实 VoiceOver、实际拖拽/系统文件面板的人工作业验收未执行。窗口事件与文件 API 测试不能覆盖这些场景。正常退出会等待当前系统调用结束；强制终止/崩溃不保证缓存清理。

用户对整体布局及 Finder/Dock 图标的验收仍由问题指南管理，本功能不替代或关闭 [NST-001](../../development/TROUBLESHOOTING.md#nst-001)、[NST-014](../../development/TROUBLESHOOTING.md#nst-014)。所有问题的统一状态见 [开发问题列表](../../development/TROUBLESHOOTING.md)。
