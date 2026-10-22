// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PodLilt",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PodLilt", targets: ["PodLilt"])],
    targets: [
        .executableTarget(
            name: "PodLilt",
            path: "Sources/PodLilt"
        )
    ]
)
