# NsToolBox macOS 开发者工具箱设计

## 1. 目标

将 NsToolBox 开发为原生 macOS 应用，首版提供开发者常用的 JSON、Base64 和 URL 工具。

首版目标平台：

- macOS 13 及以上
- Intel 与 Apple Silicon
- Universal 2 应用包

首版成功标准：

- 用户可以在一个原生 macOS 窗口中切换三个工具。
- JSON 工具可以格式化、压缩、校验和结构化对比 JSON。
- JSON 对比支持左右双栏输入、实时差异高亮和格式化后对比。
- Base64 与 URL 工具可以可靠地完成双向编解码。
- 核心逻辑不依赖网络或第三方服务。

## 2. 技术路线

采用 SwiftUI 作为应用壳体，使用少量 AppKit 桥接实现代码编辑器能力。

- SwiftUI：应用窗口、侧边栏、页面路由、工具状态和操作按钮。
- `NSViewRepresentable`：封装 `NSTextView`，提供等宽字体、语法着色和差异高亮。
- Foundation：JSON、Base64、URL 编解码和剪贴板相关能力。
- Xcode：构建 macOS Universal 2 应用。
- 首版不引入第三方依赖。

不采用纯 SwiftUI 编辑器，因为 `TextEditor` 难以满足局部文本着色和差异高亮要求；不采用 Electron、Tauri 或第三方编辑器，以避免额外运行时和依赖维护成本。

## 3. 应用结构

主窗口使用 `NavigationSplitView`：

- 左侧工具栏：JSON、Base64、URL。
- 右侧内容区：根据当前路由显示对应工具页面。
- 工具页面各自维护输入、输出和错误状态。
- 页面通过共享的剪贴板服务完成复制操作。

建议的模块边界：

```text
NsToolBoxApp
├── AppShell
├── ToolNavigation
├── JSONTool
│   ├── JSONFormatter
│   ├── JSONValidator
│   ├── JSONCompressor
│   └── JSONDiffEngine
├── EncodingTool
│   ├── Base64Codec
│   └── URLCodec
├── EditorKit
│   ├── CodeTextView
│   └── DiffTextView
└── Shared
    ├── ClipboardService
    └── Debouncer
```

逻辑服务不依赖 SwiftUI 视图，可单独进行单元测试。

## 4. JSON 数据模型与功能

内部统一使用 `JSONValue` 表示解析后的 JSON：

```text
object([String: JSONValue])
array([JSONValue])
string(String)
number(Decimal)
bool(Bool)
null
```

四项 JSON 功能共用同一套解析和序列化逻辑：

- **格式化**：输出缩进后的 JSON，便于阅读。
- **压缩**：移除不必要的空白，输出紧凑 JSON。
- **校验**：解析 JSON 并报告错误位置。
- **对比**：解析左右输入，生成结构化差异并渲染高亮。

JSON 对比规则：

- 对象字段顺序忽略。
- 数组顺序敏感。
- 数字按数值比较，`1` 与 `1.0` 视为相等。
- 新增、删除、修改分别生成差异节点。
- 差异路径使用 `user.profile.name` 和 `items[2]` 形式。
- 输入变化后经过短暂防抖再解析，避免每次按键都进行完整比较。
- 任意一侧 JSON 无效时，保留错误位置并暂停差异计算。

JSON 对比页面采用左右双栏编辑器：

- 左右分别输入 JSON。
- 支持先格式化，再对结构化数据进行比较。
- 新增、删除、修改使用不同的颜色或背景标记。
- 首版不要求左右编辑器滚动同步。

## 5. Base64 与 URL 工具

Base64 工具：

- UTF-8 文本与 Base64 双向转换。
- 解码失败时显示明确错误。
- 错误时不覆盖原始输入。

URL 工具：

- 文本进行 URL 百分号编码和解码。
- 解码失败时显示明确错误。
- 结果区支持复制。

两个工具都支持输入、输出、复制和清空操作。

## 6. 数据流与状态

通用数据流为：

```text
编辑器输入
  → 防抖
  → 工具服务处理
  → 更新结果或错误状态
  → SwiftUI 重新渲染
```

JSON 对比数据流为：

```text
左右输入
  → 分别解析为 JSONValue
  → JSONDiffEngine 递归比较
  → 生成差异节点与路径
  → DiffTextView 根据节点着色
```

ViewModel 负责协调输入和服务调用，服务层不直接操作视图。计算失败时使用显式错误状态，避免通过空字符串掩盖错误。

## 7. 错误处理

- JSON 解析错误显示行号、列号和可读错误信息。
- JSON 无效时不显示过期的差异结果。
- Base64 非法输入显示解码错误，并保留用户输入。
- URL 解码失败显示错误，并保留用户输入。
- 复制失败时显示短暂的状态提示。
- 处理过程在本地完成，不依赖网络。

## 8. 测试与验证

纯逻辑单元测试覆盖：

- JSON 格式化、压缩和校验。
- 空输入、嵌套对象、数组、Unicode 和数字处理。
- JSON 对象字段顺序差异。
- JSON 数组顺序差异。
- 新增、删除、修改节点和嵌套路径。
- Base64 正常编解码和非法输入。
- URL 正常编解码和非法输入。

macOS UI 验证覆盖：

- 工具切换。
- JSON 双栏布局。
- 输入变化后的差异更新。
- 错误提示与恢复。
- 格式化、复制和清空操作。

构建验证至少包含 Intel 和 Apple Silicon 架构，并检查 Universal 2 产物。

## 9. 首版范围边界

首版不包含：

- 文件打开和保存。
- JSON Schema 校验。
- 大文件流式处理。
- 自定义主题和插件系统。
- 云同步、网络请求和账号系统。
- 左右编辑器滚动同步。
- 第三方编辑器或在线服务依赖。

这些能力可以在首版稳定后根据实际使用反馈单独规划。
