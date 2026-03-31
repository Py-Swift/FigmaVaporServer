// swift-tools-version: 6.0
import PackageDescription

let local = false

let figma2Kv: Package.Dependency = local
    ? .package(path: "../Figma2Kv")
    : .package(url: "https://github.com/Py-Swift/Figma2Kv.git", branch: "master")

let package = Package(
    name: "FigmaVaporServer",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.102.0"),
        figma2Kv,
        .package(path: "VaporKivyReloader"),
        .package(path: "FigmaPluginUI"),
        .package(url: "https://github.com/elementary-swift/elementary.git", from: "0.6.0"),
        .package(url: "https://github.com/vapor-community/vapor-elementary.git", from: "0.1.0"),
        .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.0.0"),
    ],
    targets: [
        // Routes + WebSocket relay — importable by PySwiftKit
        .target(
            name: "FigmaRoutes",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Figma2Kv", package: "Figma2Kv"),
                .product(name: "KivyCanvasDesigner", package: "Figma2Kv"),
                .product(name: "VaporKivyReloader", package: "VaporKivyReloader"),
                .product(name: "Elementary", package: "elementary"),
                .product(name: "VaporElementary", package: "vapor-elementary"),
                .product(name: "FigmaPluginUI", package: "FigmaPluginUI"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
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
