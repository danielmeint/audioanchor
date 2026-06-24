// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AudioAnchor",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AudioAnchor",
            path: "Sources/AudioAnchor"
        )
    ],
    // Swift 5 language mode keeps the CoreAudio C-callback bridging simple;
    // we can tighten to full Swift 6 concurrency later.
    swiftLanguageModes: [.v5]
)
