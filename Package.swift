// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PodMiniPlayer",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PodMiniPlayer", targets: ["PodMiniPlayer"])],
    targets: [
        .executableTarget(
            name: "PodMiniPlayer",
            path: "Sources/PodMiniPlayer"
        )
    ]
)
