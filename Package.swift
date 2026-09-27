// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NsToolBox",
    platforms: [.macOS(.v14)],
    products: [.library(name: "ToolboxCore", targets: ["ToolboxCore"]),
               .library(name: "ToolboxUI", targets: ["ToolboxUI"]),
               .executable(name: "NsToolBox", targets: ["NsToolBox"])],
    targets: [
        .target(name: "ToolboxCore"),
        .target(name: "ToolboxImages"),
        .target(name: "ToolboxUI", dependencies: ["ToolboxCore", "ToolboxImages"]),
        .executableTarget(name: "NsToolBox", dependencies: ["ToolboxUI"]),
        .executableTarget(name: "ToolboxUITests", dependencies: ["ToolboxUI", "ToolboxCore", "ToolboxImages"]),
        .executableTarget(name: "ToolboxImageTests", dependencies: ["ToolboxImages"]),
        .executableTarget(name: "ToolboxCoreTests", dependencies: ["ToolboxCore"])
    ]
)
