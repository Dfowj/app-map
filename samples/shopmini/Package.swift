// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ShopMini",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "ShopMini", targets: ["ShopMini"])
    ],
    targets: [
        .target(name: "ShopMini", path: "Sources/ShopMini")
    ]
)
