// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MqttClientKit",
    platforms: [
        .iOS(.v15), .macOS(.v12)
    ],
    products: [
        .library(
            name: "MqttClientKit",
            targets: ["MqttClientKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/adam-fowler/mqtt-nio.git", from: "2.8.0"),
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
        .testTarget(
            name: "MqttClientKitTests",
            dependencies: ["MqttClientKit"]
        ),
    ]
)
