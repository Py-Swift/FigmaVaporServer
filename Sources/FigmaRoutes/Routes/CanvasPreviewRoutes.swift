import Vapor
import Elementary
import VaporElementary
import FigmaPluginUI

struct CanvasPreviewRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("canvas-preview") { _ async in
            let kivy = await CanvasPreviewSettings.shared.kivy
            return HTMLResponse { CanvasPreviewPage(kivyEnabled: kivy) }
        }

        routes.post("canvas-preview", "settings") { req async -> Response in
            let kivy = (try? req.query.get(Bool.self, at: "kivy")) ?? false
            await CanvasPreviewSettings.shared.setKivy(kivy)
            return Response(status: .ok)
        }
    }
}
