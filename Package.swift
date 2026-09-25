// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NsToolBox",
    platforms: [.macOS(.v13)],
    products: [.library(name: "ToolboxCore", targets: ["ToolboxCore"]),
               .library(name: "ToolboxUI", targets: ["ToolboxUI"]),
               .executable(name: "NsToolBox", targets: ["NsToolBox"])],
    targets: [
        .target(name: "ToolboxCore"),
        .target(name: "ToolboxUI", dependencies: ["ToolboxCore"]),
        .executableTarget(name: "NsToolBox", dependencies: ["ToolboxUI"]),
        .executableTarget(name: "ToolboxUITests", dependencies: ["ToolboxUI", "ToolboxCore"]),
        .executableTarget(name: "ToolboxCoreTests", dependencies: ["ToolboxCore"])
    ]
)
