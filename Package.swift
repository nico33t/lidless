// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Lidless",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Lidless", path: "Sources/Lidless")
    ]
)
