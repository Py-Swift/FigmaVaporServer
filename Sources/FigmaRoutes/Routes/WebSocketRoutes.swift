import Vapor

struct WebSocketRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {

        routes.webSocket("ws") { req, ws in
            await PluginClients.shared.add(ws)
            print("[ws] plugin connected")

            ws.onClose.whenComplete { _ in
                Task { await PluginClients.shared.remove(ws) }
                print("[ws] plugin disconnected")
            }
        }

        routes.post("command") { req -> HTTPStatus in
            guard let body = req.body.string, !body.isEmpty else {
                throw Abort(.badRequest, reason: "Empty body — expected JS code string.")
            }
            await PluginClients.shared.broadcast(encodeExec(body))
            return .ok
        }
    }
}
