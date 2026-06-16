// swift-tools-version:6.2
import PackageDescription

let vendorLib = "\(Context.packageDirectory)/vendor/.install/lib"

let nativeLibPaths: [LinkerSetting] = [
    .unsafeFlags(
        [
            "-L/opt/homebrew/lib",
            "-L\(vendorLib)",
            "-Xlinker", "-rpath", "-Xlinker", vendorLib,
        ],
        .when(platforms: [.macOS])
    )
]

let package = Package(
    name: "Bielik2D",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "Bielik2D", targets: ["Bielik2D"]),
        .library(name: "Bielik2DWeb", targets: ["Bielik2DWeb"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.52.0"),
        // Drop-in `import simd` shim for non-Apple platforms (wasm, Linux).
        // Apple platforms keep using the system `simd` framework.
        .package(url: "https://github.com/keyvariable/kvSIMD.swift.git", from: "1.1.0"),
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
            dependencies: [
                .target(name: "CSDL3", condition: .when(platforms: [.macOS])),
                .target(name: "CSDL3Shadercross", condition: .when(platforms: [.macOS])),
                // Use the `.forced` product: kvSIMD's vanilla `kvSIMD` product
                // resolves at host-package-evaluation time, where canImport(simd)
                // is always true on macOS, so it'd ship the placeholder module.
                .product(
                    name: "kvSIMD.forced",
                    package: "kvSIMD.swift",
                    condition: .when(platforms: [.wasi, .linux, .windows])
                ),
            ],
            resources: [.copy("Resources/shaders")],
            linkerSettings: nativeLibPaths
        ),
        .target(
            name: "Bielik2DWeb",
            dependencies: [
                "Bielik2D",
                .product(name: "JavaScriptKit", package: "JavaScriptKit", condition: .when(platforms: [.wasi])),
                .product(name: "JavaScriptEventLoop", package: "JavaScriptKit", condition: .when(platforms: [.wasi])),
            ]
        ),
        .testTarget(
            name: "Bielik2DTests",
            dependencies: [
                "Bielik2D",
                .target(name: "CSDL3", condition: .when(platforms: [.macOS])),
            ],
            resources: [.copy("fixtures")],
            linkerSettings: nativeLibPaths
        ),
        .executableTarget(
            name: "Bielik2DDemo",
            dependencies: [
                "Bielik2D",
                .target(name: "Bielik2DWeb", condition: .when(platforms: [.wasi])),
                .product(name: "JavaScriptKit", package: "JavaScriptKit", condition: .when(platforms: [.wasi])),
                .product(name: "JavaScriptEventLoop", package: "JavaScriptKit", condition: .when(platforms: [.wasi])),
            ],
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
