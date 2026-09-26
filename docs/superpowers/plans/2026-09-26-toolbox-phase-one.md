# 工具箱第一批扩展 Implementation Plan

> **For agentic workers:** 使用 superpowers:subagent-driven-development，按独立模块实现并审查；主任务负责集成、问题记录和构建。

**Goal:** 交付图片裁剪旋转翻转、信息透明度检测、时间戳、UUID/哈希、文本对比和批量重命名。

**Architecture:** 沿用 SwiftPM 模块，纯逻辑置于 ToolboxCore，图像计算置于 ToolboxImages，独立会话状态和界面置于 ToolboxUI。主导航仅负责切换，不共享操作参数。复用原生编辑器、图片批量处理及导出设施。

**Tech Stack:** SwiftUI / AppKit / Foundation / CoreGraphics / ImageIO / CryptoKit，macOS 14，Universal 2。

**Spec:** ../specs/2026-09-26-toolbox-expansion-proposal.md，仅第一批范围。

## Global Constraints

- macOS 14、Intel / Apple Silicon；不增加外部依赖。
- 图片处理为默认入口，工具独立状态，结果显式传递。
- 文件重命名预览后手动执行；不覆盖已有文件，失败须说明实际结果。
- 保留 UTF-8 中文、emoji；时间戳明确单位与时区。
- 核心测试使用 SwiftPM executable；不得用构建成功替代界面验证。
- 所有新问题由主任务统一递增编号写入 TROUBLESHOOTING，子任务提供实际错误、证据、修复和验证。

## Task 1: 图片编辑与信息

Files: Sources/ToolboxImages/ImageTypes.swift, ImageProcessor.swift；Sources/ToolboxUI/ImageBatchModel.swift, ImageToolView.swift 及新增图片专用文件；Sources/ToolboxImageTests/main.swift。

- [x] 添加已知彩色像素栅格测试，检查裁剪坐标、90 度旋转、双向翻转、alpha 三种状态；确认实现前失败。
- [x] 提供独立编辑模式，自由像素矩形、常用比例、旋转和翻转；以原始方向归一化后图像坐标计算，输出尺寸正确，PNG 保留透明度。非法裁剪范围拒绝。
- [x] 添加独立信息工具，展示真实格式、方向归一化尺寸、文件体积、色彩信息及实际透明度，不导出伪结果。
- [x] 复用批量输入、缓存、导出和忙碌锁定；切换后保留状态。
- [x] 执行 swift run ToolboxImageTests；输出测试证据与限制。

## Task 2: 开发小工具与纯文本对比

Files: 新建 Sources/ToolboxCore/DeveloperUtilities.swift, TextComparison.swift；Sources/ToolboxUI/DeveloperUtilityViews.swift, TextCompareView.swift；Sources/ToolboxCoreTests/UtilityTests.swift。

Interfaces: TimestampToolView、UUIDToolView、HashToolView、TextCompareView 为内部 SwiftUI 视图，各自的可注入 ObservableObject 由主导航持有；测试通过 CoreTestRunner 扩展暴露 testPhaseOneUtilities()。

- [x] 添加 epoch/毫秒/负时间、非法日期/时区、UTF-8 哈希固定向量、UUID 格式、文本插入删除与 Unicode 测试，确认实现前失败。
- [x] 时间戳秒/毫秒与 yyyy-MM-dd HH:mm:ss 日期互转，显式时区，不自动猜测单位；非法输入清除旧结果。
- [x] UUID v4 批量生成、数量有界；SHA-256/512、SHA-1、MD5 文本摘要（不称加密）。
- [x] 文本左右编辑、行级增加删除高亮、差异导航；异步计算/输入上限控制资源，过期结果不覆盖新输入。
- [x] 执行核心及相关界面状态测试，报告需主任务接入的确切接口。

## Task 3: 批量重命名

Files: 新建 Sources/ToolboxCore/BatchRename.swift；Sources/ToolboxUI/BatchRenameView.swift；Sources/ToolboxCoreTests/RenameTests.swift。

Interfaces: BatchRenameView 及可注入 BatchRenameModel，由主导航持有；CoreTestRunner.testBatchRename()。

- [x] 临时目录测试前后缀、字面替换、序号、扩展名保留、重复目标、目标已存在、原文件变化、执行与撤销，确认实现前失败。
- [x] 拖入/选择普通文件，预览原名→新名，支持排序顺序下的序号；禁用路径分隔符、非法文件名和不支持的目录/符号链接。
- [x] 执行前重验状态，绝不覆盖；逐项记录成功和失败，部分失败可定位；会话内撤销前重验身份，不修改后来替换的文件。
- [x] 保留改名记录供导出；操作仅作用于用户选择的文件，不自动执行。
- [x] 执行覆盖临时目录的真实文件测试，报告安全边界。

## Task 4: 导航、验证与交付

Files: Sources/ToolboxUI/ToolboxRootView.swift；Sources/ToolboxCoreTests/Runner.swift；Sources/ToolboxUITests/StateTests.swift 及新测试文件；README.md、问题指南与验证报告。

- [x] 在开发工具加入时间戳、UUID、哈希；新增文本和文件工具集，本批无 PDF 空入口。
- [x] 工具顶部支持横向滚动；各工具模型由根视图持有，切换不会丢输入。
- [x] 运行 swift run ToolboxCoreTests、swift run ToolboxImageTests、swift run ToolboxUITests --render --capture。
- [x] 检查最低窗口尺寸浅深色截图，验证新导航与原有 JSON/Base64/URL 交互。
- [x] 审查三个独立模块及集成，修复实际发现并补回归；统一记录问题。
- [x] ./scripts/build-app.sh；检查双架构、最低版本和签名；git diff --check。
- [x] 更新验证文档与 README，保存中文本地提交，不自动推送。

## 执行决策与进度

用户已批准第一批范围，继续在当前 codex 功能分支实现。每个子任务只修改分配文件，主任务统一修改入口和公共文档，避免共享文件冲突。第三方 API 新用法须先核对系统 SDK 声明或官方文档。

完成记录：实现提交 5d316c7 / 126fa65 / 8c49fb9；最终命令及限制见[验证记录](../validation/2026-09-26-toolbox-phase-one.md)。
