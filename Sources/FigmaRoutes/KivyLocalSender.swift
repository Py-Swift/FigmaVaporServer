import NIO
import WebSocketKit
import Vapor

/// Sends generated canvas code to the local figma-kivy-previewer WebSocket server.
final class KivyLocalSender: @unchecked Sendable {
    static let shared = KivyLocalSender()
    private weak var app: Application?

    func configure(_ app: Application) { self.app = app }

    func send(_ code: String) {
        guard let elg = app?.eventLoopGroup else {
            print("[KivyLocalSender] not configured")
            return
        }
        WebSocket.connect(to: "ws://localhost:7654", on: elg) { ws in
            ws.send(code)
            ws.onText { ws, _ in ws.close(promise: nil) }
        }.whenFailure { error in
            print("[KivyLocalSender] error: \(error)")
        }
    }
}
