import Vapor
import Foundation

// MARK: - In-memory SVG store

actor SvgStore {
    static let shared = SvgStore()
    private var svgs: [String: Data] = [:]
    private init() {}

    func store(_ data: Data, for id: String) {
        svgs[id] = data
    }

    func fetch(_ id: String) -> Data? {
        svgs[id]
    }
}

// MARK: - Routes

struct SvgRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {

        // PUT /svg/:id — Figma plugin uploads SVG string for a VECTOR node.
        routes.put("svg", ":id") { req async throws -> Response in
            guard let id = req.parameters.get("id"), !id.isEmpty else {
                throw Abort(.badRequest, reason: "Missing SVG id")
            }
            guard let body = req.body.data else {
                throw Abort(.badRequest, reason: "Empty body")
            }
            let data = Data(body.readableBytesView)
            await SvgStore.shared.store(data, for: id)
            req.logger.info("[svg] stored \(id) (\(data.count) bytes)")
            return Response(status: .noContent)
        }

        // GET /svg/:id — Container fetches SVG at preview time.
        routes.get("svg", ":id") { req async throws -> Response in
            guard let id = req.parameters.get("id"), !id.isEmpty else {
                throw Abort(.badRequest, reason: "Missing SVG id")
            }
            guard let data = await SvgStore.shared.fetch(id) else {
                req.logger.warning("[svg] not found: \(id)")
                throw Abort(.notFound, reason: "SVG '\(id)' not uploaded yet")
            }
            var headers = HTTPHeaders()
            headers.replaceOrAdd(name: .contentType, value: "image/svg+xml")
            return Response(status: .ok, headers: headers, body: .init(data: data))
        }
    }
}
