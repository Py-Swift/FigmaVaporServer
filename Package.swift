// swift-tools-version: 6.0
import PackageDescription

let local = true

let figma2Kv: Package.Dependency = local
    ? .package(path: "../Figma2Kv")
    : .package(url: "https://github.com/Py-Swift/Figma2Kv.git", branch: "master")

let package = Package(
    name: "FigmaVaporServer",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.102.0"),
        figma2Kv,
    ],
    targets: [
        // Routes + WebSocket relay — importable by PySwiftKit
        .target(
            name: "FigmaRoutes",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Figma2Kv", package: "Figma2Kv"),
            ]
        ),
        // Vapor app config — standalone lib, also importable by PySwiftKit
        .target(
            name: "FigmaApp",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .target(name: "FigmaRoutes"),
            ]
        ),
        // swift run entry point
        .executableTarget(
            name: "FigmaVaporServer",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .target(name: "FigmaApp"),
            ]
        ),
    ]
)
