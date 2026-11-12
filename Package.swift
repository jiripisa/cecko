// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "Cecko",
    platforms: [
        .macOS(.v27)
    ],
    products: [
        // The macOS app (bundle assembled by build.sh — see development_workflow.md §2).
        .executable(name: "Cecko", targets: ["Cecko"]),
        // App logic without UI — what `swift test` covers.
        .library(name: "CeckoCore", targets: ["CeckoCore"]),
    ],
    dependencies: [
        // Auto-update: the standard updater for apps outside the App Store;
        // EdDSA-signed appcast on GitHub Pages.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.4"),
    ],
    targets: [
        .target(
            name: "CeckoCore",
            path: "Sources/CeckoCore"
        ),
        .executableTarget(
            name: "Cecko",
            dependencies: [
                "CeckoCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Cecko",
            linkerSettings: [
                // Embedded frameworks ship in Contents/Frameworks (build.sh).
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
        .testTarget(
            name: "CeckoCoreTests",
            dependencies: ["CeckoCore"],
            path: "Tests/CeckoCoreTests"
        ),
    ]
)
