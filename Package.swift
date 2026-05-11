// swift-tools-version:6.2
import PackageDescription

let vendorLib = "\(Context.packageDirectory)/vendor/.install/lib"

let nativeLibPaths: [LinkerSetting] = [
    .unsafeFlags([
        "-L/opt/homebrew/lib",
        "-L\(vendorLib)",
        "-Xlinker", "-rpath", "-Xlinker", vendorLib,
    ])
]

let package = Package(
    name: "Bielik2D",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "Bielik2D", targets: ["Bielik2D"]),
    ],
    targets: [
        .systemLibrary(
            name: "CSDL3",
            path: "Sources/CSDL3"
        ),
        .systemLibrary(
            name: "CSDL3Shadercross",
            path: "Sources/CSDL3Shadercross"
        ),
        .target(
            name: "Bielik2D",
            dependencies: ["CSDL3", "CSDL3Shadercross"],
            resources: [.copy("Resources/shaders")],
            linkerSettings: nativeLibPaths
        ),
        .testTarget(
            name: "Bielik2DTests",
            dependencies: ["Bielik2D", "CSDL3"],
            resources: [.copy("fixtures")],
            linkerSettings: nativeLibPaths
        ),
        .executableTarget(
            name: "Bielik2DDemo",
            dependencies: ["Bielik2D"],
            resources: [.copy("assets")],
            linkerSettings: nativeLibPaths
        ),
        .executableTarget(
            name: "Bielik2DBenchmark",
            dependencies: ["Bielik2D"],
            resources: [.copy("assets")],
            linkerSettings: nativeLibPaths
        ),
    ]
)
