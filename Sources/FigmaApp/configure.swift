import Vapor
import FigmaRoutes

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

    try routes(app)
}
