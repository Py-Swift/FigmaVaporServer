import Vapor

/// Thread-safe registry of active WebSocket connections from the Figma plugin.
actor PluginClients {
    static let shared = PluginClients()
    private var sockets: [WebSocket] = []

    func add(_ ws: WebSocket) {
        sockets.append(ws)
    }

    func remove(_ ws: WebSocket) {
        sockets.removeAll { $0 === ws }
    }

    func broadcast(_ text: String) async {
        for ws in sockets where !ws.isClosed {
            try? await ws.send(text)
        }
    }
}
