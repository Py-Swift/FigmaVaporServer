import Vapor
import Figma2Kv
import VaporKivyReloader

struct ExecCmd: Encodable {
    let type = "exec"
    let code: String
}

struct KvRequest: Decodable {
    let kvReturn: Bool
    let kivyMode: Bool
    let body: [FigmaNode]

    enum CodingKeys: String, CodingKey {
        case kvReturn = "kv_return"
        case kivyMode = "kivy_mode"
        case body
    }
}

struct CanvasPyRequest: Decodable {
    let scalable: Bool
    let kivy: Bool
    let nodes: [FigmaNode]
}

actor CanvasPyCache {
    static let shared = CanvasPyCache()
    private var lastCode: String? = nil
    func store(_ code: String) { lastCode = code }
    func fetch() -> String? { lastCode }
}

actor CanvasStream {
    static let shared = CanvasStream()
    private var subscribers: [UUID: AsyncStream<String>.Continuation] = [:]

    func subscribe() -> (stream: AsyncStream<String>, id: UUID) {
        let id = UUID()
        var stored: AsyncStream<String>.Continuation!
        let stream = AsyncStream<String> { stored = $0 }
        subscribers[id] = stored
        return (stream, id)
    }

    func unsubscribe(_ id: UUID) {
        subscribers[id]?.finish()
        subscribers.removeValue(forKey: id)
    }

    func broadcast(_ value: String) {
        subscribers.values.forEach { $0.yield(value) }
    }
}

actor CanvasKivyClients {
    static let shared = CanvasKivyClients()
    private var count = 0

    func register() {
        count += 1
        if count == 1 {
            Task {
                if let code = await CanvasPyCache.shared.fetch() {
                    await CanvasReloader.shared.reload(code: code)
                }
            }
        }
    }

    func unregister() {
        count = max(0, count - 1)
        if count == 0 {
            Task { await CanvasReloader.shared.stop() }
        }
    }

    func hasAny() -> Bool { count > 0 }
}

/// Server-side settings for the browser /canvas-preview client.
/// Stored here so the page renders with the correct initial state on every load.
actor CanvasPreviewSettings {
    static let shared = CanvasPreviewSettings()
    private(set) var kivy: Bool = false

    func setKivy(_ value: Bool) {
        kivy = value
        if value {
            Task { await CanvasKivyClients.shared.register() }
        } else {
            Task { await CanvasKivyClients.shared.unregister() }
        }
    }
}

func encodeExec(_ code: String) -> String {
    let data = (try? JSONEncoder().encode(ExecCmd(code: code))) ?? Data()
    return String(decoding: data, as: UTF8.self)
}

