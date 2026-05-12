// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HapticBridge",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "HapticBridge",
            targets: ["HapticBridge"]
        ),
        .executable(
            name: "haptic-bridge-host",
            targets: ["HapticBridgeHost"]
        )
    ],
    targets: [
        .target(
            name: "HapticBridge",
            path: "Sources/HapticBridge"
        ),
        .executableTarget(
            name: "HapticBridgeHost",
            path: "Sources/HapticBridgeHost"
        ),
        .testTarget(
            name: "HapticBridgeTests",
            dependencies: ["HapticBridge"],
            path: "Tests/HapticBridgeTests"
        )
    ]
)
