# NsToolBox

SwiftUI + AppKit 原生 macOS 工具箱，包含开发、图片、文本与文件工具。最低 macOS 14，支持 Intel 和 Apple Silicon，所有数据均在本地处理。

当前版本为 **1.0.0**（构建号 2），版本标签为 `v1.0.0`。功能变化见 [更新日志](CHANGELOG.md)，验证范围与发布边界见 [1.0 验证记录](docs/releases/1.0.0.md)。

## 快速开始

在 macOS 上从仓库根目录执行：

```sh
./scripts/build-app.sh
open build/NsToolBox.app
```

启动后默认进入「图片处理」：选择顶部工具，添加图片，调整参数并执行，再点击「导出结果…」保存。切换到左侧「开发工具」可使用 JSON、编码与时间戳等功能。关闭窗口前请复制文本结果、导出处理后的图片；输入和工具会话不会跨次启动保存。

## 开发工具

- **JSON**：实时格式化、压缩、校验，错误显示行列位置；左右双栏结构化对比、差异高亮、点击路径定位、格式化两侧。
- **Base64**：UTF-8 文本与标准 Base64 编解码，支持带空白/换行的输入，拒绝非法填充及非 UTF-8 解码结果。
- **URL**：文本/参数值的百分号编解码；编码仅保留字母、数字、连字符、句点、下划线和波浪线，完整 URL 中的分隔符也会编码；解码保留加号，不按表单规则转换为空格。
- **时间戳**：实时 Unix 秒/毫秒、标准日期与 ISO 8601 双向转换、快捷时区、批量逐行转换、时间差计算；保留毫秒精度，拒绝无效日期和夏令时重复本地时间。
- **UUID**：批量生成 1～1000 个 UUID v4。
- **哈希**：UTF-8 文本的 SHA-256、SHA-512、SHA-1、MD5 摘要，最多 2 MiB；哈希不是加密。
- 输入与输出分别可复制；切换工具保留当前窗口的输入，清空时取消旧处理结果。关闭窗口后不保留输入。

JSON 对比忽略对象字段顺序，数组按索引比较、顺序敏感，数字按精确数值比较（1 与 1.0 相等）。格式化保留数字原文，不通过 Double/Decimal 中转，避免大整数与指数精度损失。重复对象字段报错；嵌套深度最多 256 层；错误列号及编辑器定位使用 UTF-16。

## 图片处理

先选择抠图、缩放、格式转换、压缩、裁剪旋转或图片信息，再批量添加或拖入 PNG / JPG。处理类工具使用当前操作按钮执行；图片信息导入后直接展示。各工具保留独立图片、参数、错误和结果，格式转换不会继承抠图步骤。

原图和结果并排预览。「继续处理」将选中结果复制到另一个工具，确认参数后手动执行下一步；原工具内容保留。「导出结果…」保存当前工具的全部成功结果到所选目录，自动编号避免覆盖原图或同名文件。

- 本地自动去背景、人像抠图；白底文字、图标可选「去白底」并调整容差。按颜色去底也会清除主体中的白色，复杂阴影可能保留浅边。
- 像素矩形或常用比例裁剪，90° 旋转及水平/垂直翻转；坐标从方向归一化后的左上角起算，先裁剪再旋转、最后翻转，预览后导出。
- 图片信息展示真实格式、尺寸、体积、色彩及透明度；区分无 Alpha、Alpha 全不透明、实际存在透明像素，支持 16 位 PNG 极浅透明检测。
- 按百分比或指定宽高缩放，默认保持比例并保留每张图片的原格式。
- PNG / JPG 互转；PNG 支持透明度，但转换格式不会自动清除原背景。需要透明底请使用抠图；JPG 可选底色与质量。
- PNG 未改变尺寸、不抠图且无需校正方向时保留原文件字节；像素处理会输出 8 位 sRGB，不保证文件更小。取消在当前系统调用结束后生效。
- 限制单帧图片、单张 4000 万像素，输出单边最多 16384 像素；文件在当前会话缓存，正常退出清理。崩溃或强制终止不保证执行清理。

实现与验证见 [图片处理设计](docs/superpowers/specs/2026-09-25-image-tools-design.md)、[首轮验证记录](docs/superpowers/validation/2026-09-26-image-tools.md) 和 [独立工具修正验证](docs/superpowers/validation/2026-09-26-independent-image-tools.md)。

## 文本与文件工具

- **纯文本对比**：左右输入、行级增删高亮、上一处/下一处跳转；每侧最多 128 KiB UTF-8、2000 行。
- **批量重命名**：添加或拖入普通文件，设置前后缀、字面替换与序号，扩展名保持不变；通过每行菜单调整顺序，预览冲突后手动执行。已有目标不会覆盖，成功/失败逐项记录；可撤销本会话改名并导出 TSV 操作记录。
- 重命名拒绝目录、符号链接和互占目标；执行/撤销前检查文件身份和外部修改。外部改动或原名占用会阻止撤销，失败项保留重试。首版文件预览/执行为同步操作，不面向海量文件基准。

第一批范围与边界见 [扩展建议](docs/superpowers/specs/2026-09-26-toolbox-expansion-proposal.md)、[验证记录](docs/superpowers/validation/2026-09-26-toolbox-phase-one.md)。PDF、OCR、拼图与水印属于后续候选，尚未实现。

## 界面布局

应用启动或新建窗口时默认打开「图片处理」。左侧按工具集分类，包含「开发工具」「图片处理」「文本工具」「文件工具」；开发工具顶部切换 JSON、Base64、URL、时间戳、UUID 和哈希，图片处理顶部有六个独立入口。各工具采用紧凑双栏，左侧输入、右侧结果，JSON 对比时两侧均可编辑。支持拖动分栏、行号、当前行提示、单侧清空、校验错误定位和折叠差异列表，外观跟随系统明暗。

导航按钮保留可点击边界，当前项使用青绿底色和边框，悬停时提供反馈。主要执行动作使用强调色，普通操作使用中性按钮，不可用命令变淡；复制与清空图标有独立按钮边界和悬停说明，静态标题不使用按钮外观。

布局设计与验证见 [紧凑工作区规划](docs/superpowers/specs/2026-09-25-compact-workspace-design.md) 和 [验证记录](docs/superpowers/validation/2026-09-25-compact-workspace.md)。

## 构建和运行

需要 Swift 5.9+ 和匹配的 macOS SDK；可使用完整 Xcode 15+，或已安装对应 SDK 的 Command Line Tools。

    swift run NsToolBox

生成 Universal 2 应用：

    ./scripts/build-app.sh
    open build/NsToolBox.app

脚本分别构建 arm64、x86_64 Release 二进制，验证架构后合并并做 ad-hoc 本地签名。默认输出 build/NsToolBox.app，可直接打开或复制到 Applications。

若使用 Xcode，打开 NsToolBox.xcodeproj，选择 NsToolBox scheme。工程通过本地 Swift Package 复用核心与界面源文件，无外部依赖。Release 的 ONLY_ACTIVE_ARCH 为 NO，最低部署目标为 14.0。正式对外分发前需配置自己的 Bundle ID、开发者证书与公证；当前产物是本地开发版。

## 测试

为了让只有 Command Line Tools、没有 XCTest 的机器也能运行测试，测试以 SwiftPM 可执行目标提供：

    swift run ToolboxCoreTests
    swift run ToolboxImageTests
    swift run ToolboxUITests

可选原生界面渲染检查（需要登录图形会话）：

    swift run ToolboxUITests --render

增加 `--capture` 可截取测试进程自身窗口；测试会暂时显示测试窗口。渲染结果位于 build/previews。测试覆盖 JSON 无损处理、非法输入、数字精度、UTF-16 源范围、结构化差异、编解码、时间戳边界、图片像素与透明度、文件重命名及撤销、状态恢复、防抖、编辑器语法色和文本撤销。它们不是 XCTest 目标，请使用以上命令运行。

## 版本维护

- `master` 用作 1.0 起的版本整合分支，开发在 `codex/` 前缀的分支进行；原 `main` 保留历史，不因本次整合删除或改写。
- 应用版本与构建号统一维护在 `Resources/Info.plist`，命令行打包和 Xcode 均使用此文件。后续版本同时更新 [更新日志](CHANGELOG.md)，以 `v主版本.次版本.修订号` 标签固定版本。
- 合并前运行上述三个测试目标、原生工作流、Universal 2 构建和 `git diff --check`，在 `docs/releases` 记录实际结果。问题状态始终以 [问题指南](docs/development/TROUBLESHOOTING.md) 为准。

## 问题记录与排障

遇到问题先查阅 [开发问题列表与修复指南](docs/development/TROUBLESHOOTING.md)，按编号、现象或错误信息查找复现步骤、定位证据、修复方法和验证结果。

后续每次开发遇到新问题，都使用 [问题模板](docs/development/ISSUE_TEMPLATE.md) 在同一次任务交付前补全记录；同一问题复发更新原条目并保留历史。持续维护规则已写入 [AGENTS.md](AGENTS.md)。Finder / Dock 图标显示问题的当前进展见 [NST-001](docs/development/TROUBLESHOOTING.md#nst-001)。

## 项目结构

- Sources/NsToolBox：SwiftUI 应用入口。
- Sources/ToolboxUI：工具导航、页面、状态模型、NSTextView 桥接与剪贴板。
- Sources/ToolboxCore：JSON、编码、时间戳、摘要、文本对比与文件重命名逻辑。
- Sources/ToolboxImages：ImageIO 编解码、缩放、透明合成和 Vision 本地抠图。
- Sources/ToolboxCoreTests、Sources/ToolboxImageTests、Sources/ToolboxUITests：可执行行为测试。
- NsToolBox.xcodeproj、Resources、scripts：Xcode 工程、应用元数据与打包脚本。
- docs/superpowers：已批准设计、实现计划和验证记录。
- docs/development：持续维护的问题列表、修复指南与记录模板。
- docs/releases：各版本的验证证据、版本元数据与交付边界。

开发工具暂不包含文本文件导入保存、JSON Schema、大文件流式处理、同步滚动、账号、云同步及插件系统。Intel/M 系列和 macOS 14 的完整实机矩阵仍需在对应设备上验收；构建架构与最低版本检查不能代替实机测试。

## 应用图标

“大乱炖”图标以一口装着 JSON、代码和链接符号的炖锅，表达工具集合的定位。可编辑源文件为 Resources/AppIcon.svg，提供 PNG 和 ICNS；命令行与 Xcode 构建均打包该图标。

如需重新导出（需要 librsvg 的 rsvg-convert）：

    ./scripts/generate-app-icon.sh
