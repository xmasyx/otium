// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Otium",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "OtiumCore", targets: ["OtiumCore"]),
        .executable(name: "OtiumApp", targets: ["OtiumApp"]),
    ],
    targets: [
        .target(
            name: "OtiumCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "OtiumApp",
            dependencies: ["OtiumCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "OtiumCoreTests",
            dependencies: ["OtiumCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
