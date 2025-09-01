// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MqttClientKit",
    platforms: [
        .iOS(.v17), .macOS(.v14)
    ],
    products: [
        .library(
            name: "MqttClientKit",
            targets: ["MqttClientKit"]
        ),
        .library(
            name: "MqttFeatures",
            targets: ["MqttClientKit"]
        ),
        .library(
            name: "Examples",
            targets: ["Examples"]
        )

    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server-community/mqtt-nio", from: "2.11.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "MqttClientKit",
            dependencies: [
                .product(name: "MQTTNIO", package: "mqtt-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .target(
            name: "Examples",
            dependencies: [
                "MqttClientKit",
                .product(name: "MQTTNIO", package: "mqtt-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ],
            resources: [
                .copy("README.md")
            ]
        ),
        .testTarget(
            name: "MqttClientKitTests",
            dependencies: ["MqttClientKit"]
        )
    ]
)
