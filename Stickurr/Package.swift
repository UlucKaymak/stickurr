// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Stickurr",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Stickurr",
            path: "Sources/Stickurr"
        )
    ]
)
