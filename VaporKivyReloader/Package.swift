// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VaporKivyReloader",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "VaporKivyReloader", targets: ["VaporKivyReloader"]),
    ],
    targets: [
        .target(
            name: "VaporKivyReloader",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
