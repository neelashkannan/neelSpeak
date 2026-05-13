// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NeelSpeak",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NeelSpeak", targets: ["VoiceTyper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.14.4"),
        .package(url: "https://github.com/ml-explore/mlx-swift-examples.git", exact: "2.29.1"),
    ],
    targets: [
        .executableTarget(
            name: "VoiceTyper",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                .product(name: "MLXLMCommon", package: "mlx-swift-examples"),
            ],
            path: "Sources/VoiceTyper",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
