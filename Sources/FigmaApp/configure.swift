import Vapor
import FigmaRoutes
import VaporKivyReloader
import Foundation

public func configure(_ app: Application) throws {
    // Allow large Figma node payloads (trees can be several MB)
    app.routes.defaultMaxBodySize = "20mb"

    // CORS — allow requests from the Figma plugin iframe
    let corsConfig = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .OPTIONS],
        allowedHeaders: [.accept, .contentType, .origin, .xRequestedWith]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfig), at: .beginning)

    // Serve static files from Public/ (WASM binaries, runtime JS, etc.)
    let publicDir = app.directory.workingDirectory + "Public"
    app.middleware.use(FileMiddleware(publicDirectory: publicDir))

    app.http.server.configuration.port = 8765

    let lanIP = localLANAddresses().first ?? "localhost"
    app.logger.notice("Server:     http://\(lanIP):8765")

    BonjourAnnouncer.shared.start(port: 8765)
    Task { await DeviceReloader.shared.setLanIP(lanIP) }

    try routes(app)
}

private func localLANAddresses() -> [String] {
    let p = Process()
    let pipe = Pipe()
    p.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    guard (try? p.run()) != nil else { return [] }
    p.waitUntilExit()
    return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        .components(separatedBy: "\n")
        .compactMap { line -> String? in
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("inet "), !t.hasPrefix("inet 127.") else { return nil }
            return t.components(separatedBy: " ").dropFirst().first
        }
}
