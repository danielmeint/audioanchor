// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AudioAnchor",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AudioAnchor",
            path: "Sources/AudioAnchor"
        )
    ]
)
