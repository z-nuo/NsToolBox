# 图片处理工具集实施计划

> 使用 superpowers:subagent-driven-development；独立核心和页面子任务并行，主代理集成队列并统一验证。

**目标：** 实现已批准的本地批量图片处理与非覆盖导出。

**架构：** ToolboxImages 提供纯后台处理接口；ImageBatchModel 管理会话、串行任务和缓存；ImageToolView 编辑共享参数并预览选中项。

**技术栈：** SwiftUI、AppKit、ImageIO、CoreImage、Vision；macOS 14，Universal 2，无第三方依赖。

**规格：** [图片处理设计](../specs/2026-09-25-image-tools-design.md)。

## 全局约束

PNG/JPG、本地处理、逐张执行、保留原图、导出不覆盖同名、错误逐项隔离；限制与取消行为见规格。

## 任务与接口

- [x] 核心：Sources/ToolboxImages/ImageProcessor.swift。实现 static inspect(url: URL) throws -> ImageInfo 和 static process(url: URL, options: ImageProcessingOptions) throws -> ProcessedImage，类型见 ImageTypes.swift。ImageIO 正规化 EXIF 方向；抠图之后缩放并编码；测试生成的小图不依赖网络。
- [x] 页面：Sources/ToolboxUI/ImageToolView.swift。消费 ImageBatchModel，顶部四标签共享 options。NSOpenPanel 多选、拖拽 file URLs、目录导出、列表、棋盘格前后预览和单项错误。
- [x] 队列：Sources/ToolboxUI/ImageBatchModel.swift，串行工作队列、导入源快照、结果缓存、取消和状态。根路由持有模型，切换分类不释放数据。
- [x] 平台：Package.swift 新增 ToolboxImages 与 ToolboxImageTests，最低 v14；Info.plist、Xcode 两配置和脚本 triple 同步 14.0。
- [x] 验证：swift run ToolboxImageTests、swift run ToolboxCoreTests、swift run ToolboxUITests --render --capture、scripts/build-app.sh；检查原生图片窗口与 Vision 能力，记录未能执行的实机项。
- [x] 文档：更新 README、AGENTS 测试入口、NST-018 与新问题；git diff --check，审查并提交。

测试核心断言：200×100 按 50% 输出 100×50；按 80×80 保持比例输出 80×40；PNG alpha 保留，JPG 底色可见；无效质量/尺寸失败；重复导出两个不同路径且旧文件内容不变。

实际结果与未执行边界见 [验证记录](../validation/2026-09-26-image-tools.md)。截图和深色预览问题记录在 NST-017 / NST-024，后者标为已规避，未宣称根因已确认。
