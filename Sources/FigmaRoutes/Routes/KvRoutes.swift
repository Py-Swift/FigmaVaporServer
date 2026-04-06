import Vapor
import FigmaTranslator
import VaporKivyReloader

struct KvRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {

        routes.post("json-dump") { req -> HTTPStatus in
            guard let body = req.body.string, !body.isEmpty else {
                throw Abort(.badRequest, reason: "Empty body — expected JSON array of Figma nodes.")
            }
            do {
                let nodes = try JSONDecoder().decode([FigmaNode].self, from: Data(body.utf8))
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let pretty = try encoder.encode(nodes)
                print(String(decoding: pretty, as: UTF8.self))
            } catch {
                print("Decode error: \(error)")
            }
            return .ok
        }

        routes.post("kv") { req -> String in
            guard let raw = req.body.string, !raw.isEmpty else {
                throw Abort(.badRequest, reason: "Empty body — expected JSON object with kv_return, kivy_mode, body.")
            }
            do {
                let request = try JSONDecoder().decode(KvRequest.self, from: Data(raw.utf8))
                let kv = FigmaMapper.convert(nodes: request.body)
                if request.kivyMode {
                    await KivyReloader.shared.reload(kv: kv)
                }
                return request.kvReturn ? kv : ""
            } catch {
                throw Abort(.unprocessableEntity, reason: "Conversion failed: \(error)")
            }
        }
    }
}
