import Vapor
import Foundation
import ServerFontManager

struct FontRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("font", ":family") { req async throws -> Response in
            guard let family = req.parameters.get("family") else {
                throw Abort(.badRequest)
            }
            req.logger.info("[font] request: \(family)")
            guard let (data, resolvedURL) = await ServerFontManager.fontData(for: family) else {
                req.logger.warning("[font] not found: \(family)")
                throw Abort(.notFound, reason: "Font '\(family)' not found on host or Google Fonts")
            }
            req.logger.info("[font] resolved: \(resolvedURL.path) (\(data.count) bytes)")
            var headers = HTTPHeaders()
            headers.replaceOrAdd(name: .contentType, value: "font/ttf")
            return Response(status: .ok, headers: headers, body: .init(data: data))
        }

        routes.get("fonts") { req async throws -> Response in
            let families = ServerFontManager.availableFonts
            let body = try JSONSerialization.data(withJSONObject: ["count": families.count, "fonts": families])
            var headers = HTTPHeaders()
            headers.replaceOrAdd(name: .contentType, value: "application/json")
            return Response(status: .ok, headers: headers, body: .init(data: body))
        }
    }
}
