import Vapor
import Elementary
import VaporElementary
import FigmaPluginUI

struct LabRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {

        routes.get("lab") { _ in
            HTMLResponse { LabPage() }
        }
        
        routes.post("lab", "action") { req async -> String in
            struct ActionBody: Decodable { let action: String }
            let action = (try? req.content.decode(ActionBody.self))?.action ?? "(unknown)"
            switch action {
            case "hello":
                print("[Lab] Hello from the plugin!")
                return "Hello back! Check your server terminal."
            case "ping":
                print("[Lab] Ping received")
                return "Pong!"
            case "dump-cache":
                let code = await CanvasPyCache.shared.fetch() ?? "(empty)"
                let preview = code.count > 200 ? String(code.prefix(200)) + "..." : code
                print("[Lab] Canvas cache:\n\(preview)")
                return "Dumped \(code.count) chars to server terminal."
            default:
                print("[Lab] Unknown action: \(action)")
                return "Unknown action: \(action)"
            }
        }
    }
}
