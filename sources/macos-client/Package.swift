// swift-tools-version: 6.0

import Foundation
import PackageDescription

let infoPlistPath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Info.plist")
    .path

let package = Package(
    name: "RemoteMeetingMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "RemoteMeetingMac", targets: ["RemoteMeetingMac"])
    ],
    dependencies: [
        .package(url: "https://github.com/livekit/client-sdk-swift.git", .upToNextMajor(from: "2.15.1"))
    ],
    targets: [
        .executableTarget(
            name: "RemoteMeetingMac",
            dependencies: [
                .product(name: "LiveKit", package: "client-sdk-swift")
            ],
            path: "Sources/RemoteMeetingMac",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", infoPlistPath,
                ])
            ]
        )
    ]
)
