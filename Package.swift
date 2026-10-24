// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NeelSpeak",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NeelSpeak", targets: ["VoiceTyper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.17.7"),
    ],
    targets: [
        .executableTarget(
            name: "VoiceTyper",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            path: "Sources/VoiceTyper",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .testTarget(
            name: "NeelSpeakTests",
            dependencies: ["VoiceTyper"],
            path: "Tests/NeelSpeakTests",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
