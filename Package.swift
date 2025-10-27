// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SmallLight",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SmallLight", targets: ["SmallLightAppHost"])
    ],
    targets: [
        .target(
            name: "SmallLightDomain"
        ),
        .target(
            name: "SmallLightServices",
            dependencies: [
                "SmallLightDomain"
            ]
        ),
        .target(
            name: "SmallLightUI",
            dependencies: [
                "SmallLightDomain",
                "SmallLightServices"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "SmallLightAppHost",
            dependencies: [
                "SmallLightUI"
            ],
            path: "Sources/SmallLightAppHost",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SmallLightTests",
            dependencies: [
                "SmallLightDomain",
                "SmallLightServices"
            ]
        ),
        .testTarget(
            name: "SmallLightUITests",
            dependencies: [
                "SmallLightUI"
            ]
        ),
        .testTarget(
            name: "SmallLightSystemTests",
            dependencies: [
                "SmallLightAppHost"
            ]
        )
    ]
)
