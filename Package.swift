// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Steward",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Steward"
        ),
    ]
)
