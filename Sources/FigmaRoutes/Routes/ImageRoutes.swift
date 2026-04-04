import Vapor
import Foundation

// MARK: - In-memory image store

actor ImageStore {
    static let shared = ImageStore()
    private var images: [String: Data] = [:]
    private init() {}

    func store(_ data: Data, for hash: String) {
        images[hash] = data
    }

    func fetch(_ hash: String) -> Data? {
        images[hash]
    }
}

// MARK: - Routes

struct ImageRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {

        // PUT /image/:hash — Figma plugin uploads raw image bytes.
        routes.put("image", ":hash") { req async throws -> Response in
            guard let hash = req.parameters.get("hash"), !hash.isEmpty else {
                throw Abort(.badRequest, reason: "Missing image hash")
            }
            guard let body = req.body.data else {
                throw Abort(.badRequest, reason: "Empty body")
            }
            let data = Data(body.readableBytesView)
            await ImageStore.shared.store(data, for: hash)
            req.logger.info("[image] stored \(hash) (\(data.count) bytes)")
            return Response(status: .noContent)
        }

        // GET /image/:hash — Docker container fetches image at preview time.
        routes.get("image", ":hash") { req async throws -> Response in
            guard let hash = req.parameters.get("hash"), !hash.isEmpty else {
                throw Abort(.badRequest, reason: "Missing image hash")
            }
            guard let data = await ImageStore.shared.fetch(hash) else {
                req.logger.warning("[image] not found: \(hash)")
                throw Abort(.notFound, reason: "Image '\(hash)' not uploaded yet")
            }
            var headers = HTTPHeaders()
            headers.replaceOrAdd(name: .contentType, value: "image/png")
            return Response(status: .ok, headers: headers, body: .init(data: data))
        }
    }
}
