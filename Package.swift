// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "warble",
    platforms: [.macOS("26.0")],
    dependencies: [
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            revision: "300165b240c45375add402265f62410b6df33cf1"
        )
    ],
    targets: [
        .target(
            name: "WarbleKit",
            dependencies: [.product(name: "FluidAudio", package: "FluidAudio")],
            path: "Sources/WarbleKit",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .executableTarget(
            name: "warble",
            dependencies: ["WarbleKit"],
            path: "Sources/Warble"
        ),
        .testTarget(
            name: "WarbleKitTests",
            dependencies: ["WarbleKit"],
            path: "Tests/WarbleKitTests"
        ),
    ]
)
