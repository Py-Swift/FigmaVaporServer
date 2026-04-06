// swift-tools-version: 6.2
import PackageDescription

let local = true

let figmaTranslator: Package.Dependency = local
    ? .package(path: "../FigmaTranslator")
    : .package(url: "https://github.com/Py-Swift/FigmaTranslator.git", branch: "master")

let package = Package(
    name: "FigmaVaporServer",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.102.0"),
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.0.0"),
        figmaTranslator,
        .package(path: "packages/VaporKivyReloader"),
        .package(path: "packages/FigmaPluginUI"),
        .package(path: "packages/ServerFontManager"),
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
                .product(name: "FigmaTranslator", package: "FigmaTranslator"),
                .product(name: "KivyCanvasDesigner", package: "FigmaTranslator"),
                .product(name: "KivyWidgetDesigner", package: "FigmaTranslator"),
                .product(name: "VaporKivyReloader", package: "VaporKivyReloader"),
                .product(name: "Elementary", package: "elementary"),
                .product(name: "VaporElementary", package: "vapor-elementary"),
                .product(name: "FigmaPluginUI", package: "FigmaPluginUI"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "WebSocketKit", package: "websocket-kit"),
                .product(name: "ServerFontManager", package: "ServerFontManager"),
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
