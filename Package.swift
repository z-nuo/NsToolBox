// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NsToolBox",
    platforms: [.macOS(.v13)],
    products: [.library(name: "ToolboxCore", targets: ["ToolboxCore"]),
               .executable(name: "NsToolBox", targets: ["NsToolBox"])],
    targets: [
        .target(name: "ToolboxCore"),
        .executableTarget(name: "NsToolBox", dependencies: ["ToolboxCore"]),
        .executableTarget(name: "ToolboxCoreTests", dependencies: ["ToolboxCore"])
    ]
)
