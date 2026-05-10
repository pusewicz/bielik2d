// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Bielik2D",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "Bielik2D", targets: ["Bielik2D"]),
    ],
    targets: [
        .target(name: "Bielik2D"),
        .testTarget(name: "Bielik2DTests", dependencies: ["Bielik2D"]),
    ]
)
