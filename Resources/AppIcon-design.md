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
