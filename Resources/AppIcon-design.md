# 大乱炖 · 应用图标

为 NsToolBox 绘制的原创矢量图标，主题为“一口炖着开发工具的小锅”。

- 深蓝搪瓷炖锅：统一的工具箱容器。
- 橙色汤底、蒸汽和暖色火焰标记：大乱炖的烹饪意象。
- 薄荷色花括号、金色代码符号、珊瑚色链环：JSON、开发工具和 URL。
- 奶油色圆角底板：保持 Dock 中的清晰轮廓。

图形全部使用 SVG 路径，无字体或远程素材依赖。本次为直接绘制的矢量设计，未使用 AI 图像生成工具或 API。

## 文件

- AppIcon.svg：可编辑源文件，1024 × 1024 画布，透明外边角。
- AppIcon.png：1024 × 1024 PNG。
- AppIcon-preview.png：512 × 512 预览。
- AppIcon.icns：包含 16、32、128、256、512 点的 1x/2x 图像，最大 1024 像素。

修改 SVG 后，运行 scripts/generate-app-icon.sh 重新导出。重新绘制 PNG 需要 librsvg 的 rsvg-convert；应用运行和正常打包不依赖它。

Info.plist 的 CFBundleIconFile、Xcode Copy Bundle Resources 与命令行 build-app.sh 均引用 AppIcon.icns。已在运行中的应用可能需要下次启动才更新 Dock 图标。

## 本地重复构建与图标刷新

以下为历史排查说明；当前状态、后续证据与关闭条件统一维护在 [NST-001：Finder / Dock 不显示应用图标](../docs/development/TROUBLESHOOTING.md#nst-001)。

命令行打包会覆盖已有 .app 内的文件。只覆盖 Contents 下的文件不会更新应用包目录自身的修改时间；Finder/Dock 等使用应用包元数据的进程可能继续显示旧图标。

build-app.sh 在完成签名验证后更新 .app 目录时间，并通过 lsregister -f 重新注册该应用，不重置其他应用的注册信息，也不会自动退出应用或重启 Dock。已验证重复构建前后目录时间递增，签名仍有效。

2026-09-25 排查时，原始 ICNS、NSWorkspace 和 NSRunningApplication 在 16～512 像素均可渲染出图标，但用户反馈 Finder/Dock 仍不显示，因此这些 API 检查不能代替实际显示确认。本次另行刷新了 Finder 的构建目录并重启 Dock，保持原有应用进程运行；可见效果需以用户端显示为准。
