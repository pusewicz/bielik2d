// swift-tools-version:6.2
import PackageDescription

let homebrewLib: [LinkerSetting] = [
    .unsafeFlags(["-L/opt/homebrew/lib"])
]

let package = Package(
    name: "Bielik2D",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Bielik2D", targets: ["Bielik2D"]),
    ],
    targets: [
        .systemLibrary(
            name: "CSDL3",
            path: "Sources/CSDL3"
        ),
        .target(
            name: "Bielik2D",
            dependencies: ["CSDL3"],
            linkerSettings: homebrewLib
        ),
        .testTarget(
            name: "Bielik2DTests",
            dependencies: ["Bielik2D", "CSDL3"],
            linkerSettings: homebrewLib
        ),
    ]
)
