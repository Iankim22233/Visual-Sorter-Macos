// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SortLab",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "SortLab", path: "Sources/SortLab")
    ]
)
