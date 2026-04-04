// swift-tools-version: 6.0
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "FigmaPluginUI",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "FigmaPluginUI", targets: ["FigmaPluginUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/elementary-swift/elementary.git", from: "0.6.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
    ],
    targets: [
        .target(
            name: "FigmaPluginUI",
            dependencies: [
                .product(name: "Elementary", package: "elementary"),
                "PluginUIMacros",
            ]
        ),
        .macro(
            name: "PluginUIMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
    ]
)
