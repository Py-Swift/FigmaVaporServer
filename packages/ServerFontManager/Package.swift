// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ServerFontManager",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ServerFontManager", targets: ["ServerFontManager"]),
    ],
    targets: [
        .target(name: "ServerFontManager", swiftSettings: [.swiftLanguageMode(.v5)]),
        .plugin(
            name: "GenerateFontIndex",
            capability: .command(
                intent: .custom(
                    verb: "generate-font-index",
                    description: "Fetch the Google Fonts list from gwfh.mranftl.com (1 request, no API key) and bake it into GeneratedFontIndex.swift so the server needs zero network calls for the index."
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Writes Sources/ServerFontManager/GeneratedFontIndex.swift"),
                    .allowNetworkConnections(
                        scope: .all(ports: [443]),
                        reason: "Fetches Google Fonts folder index from api.github.com"
                    ),
                ]
            )
        ),
    ]
)
