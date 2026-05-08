// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "RemoteDockShared",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "RemoteDockCore", targets: ["RemoteDockCore"]),
        .library(name: "RemoteDockProtocol", targets: ["RemoteDockProtocol"]),
        .library(name: "RemoteDockTransport", targets: ["RemoteDockTransport"])
    ],
    targets: [
        .target(name: "RemoteDockCore"),
        .target(
            name: "RemoteDockProtocol",
            dependencies: ["RemoteDockCore"]
        ),
        .target(
            name: "RemoteDockTransport",
            dependencies: ["RemoteDockProtocol"]
        ),
        .testTarget(
            name: "RemoteDockCoreTests",
            dependencies: ["RemoteDockCore"]
        ),
        .testTarget(
            name: "RemoteDockProtocolTests",
            dependencies: ["RemoteDockProtocol"]
        ),
        .testTarget(
            name: "RemoteDockTransportTests",
            dependencies: ["RemoteDockTransport"]
        )
    ]
)
