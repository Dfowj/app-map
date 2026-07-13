// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "appmap",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0"),
    ],
    targets: [
        .target(name: "AppMapKit", dependencies: ["Yams"]),
        .executableTarget(
            name: "appmap",
            dependencies: [
                "AppMapKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "AppMapKitTests", dependencies: ["AppMapKit"]),
    ]
)
