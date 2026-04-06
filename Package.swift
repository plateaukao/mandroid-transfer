// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MandroidTransfer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MandroidTransfer",
            path: "Sources"
        )
    ]
)
