import Vapor
import FigmaTranslator
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

/// Tracks the last known canvas window size so we can decide whether to hot-reload
/// or restart the container when lock mode is on.
actor CanvasWindowSize {
    static let shared = CanvasWindowSize()
    private var width:  Int = 0
    private var height: Int = 0
    private init() {}

    /// Store new dimensions. Returns `true` if they differ from the previous values.
    func update(width: Int, height: Int) -> Bool {
        let changed = self.width != width || self.height != height
        self.width  = width
        self.height = height
        return changed
    }
}

// MARK: - Widget mode shared state

actor WidgetPyCache {
    static let shared = WidgetPyCache()
    private var lastCode: String? = nil
    func store(_ code: String) { lastCode = code }
    func fetch() -> String? { lastCode }
}

actor WidgetStream {
    static let shared = WidgetStream()
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

actor WidgetKivyClients {
    static let shared = WidgetKivyClients()
    private var count = 0

    func register() {
        count += 1
        if count == 1 {
            Task {
                if let code = await WidgetPyCache.shared.fetch() {
                    await CanvasReloader.shared.reload(code: code)
                }
            }
        }
    }

    func unregister() {
        count = max(0, count - 1)
    }

    func hasAny() -> Bool { count > 0 }
}

actor WidgetWindowSize {
    static let shared = WidgetWindowSize()
    private var width:  Int = 0
    private var height: Int = 0
    private init() {}

    func update(width: Int, height: Int) -> Bool {
        let changed = self.width != width || self.height != height
        self.width  = width
        self.height = height
        return changed
    }
}

// MARK: - Lock state (synced across browser + plugin via SSE)

/// Stores the current lock on/off state for canvas mode and broadcasts changes
/// to all SSE subscribers so the browser and plugin stay in sync.
actor CanvasLockState {
    static let shared = CanvasLockState()
    private var enabled = false
    private var subscribers: [UUID: AsyncStream<Bool>.Continuation] = [:]
    private init() {}

    func set(_ value: Bool) {
        enabled = value
        subscribers.values.forEach { $0.yield(value) }
    }

    func current() -> Bool { enabled }

    /// Subscribe and immediately receive the current state as the first event.
    func subscribe() -> (stream: AsyncStream<Bool>, id: UUID) {
        let id = UUID()
        let snapshot = enabled
        var stored: AsyncStream<Bool>.Continuation!
        let stream = AsyncStream<Bool> { cont in
            stored = cont
            cont.yield(snapshot)
        }
        subscribers[id] = stored
        return (stream, id)
    }

    func unsubscribe(_ id: UUID) {
        subscribers[id]?.finish()
        subscribers.removeValue(forKey: id)
    }
}

actor WidgetLockState {
    static let shared = WidgetLockState()
    private var enabled = false
    private var subscribers: [UUID: AsyncStream<Bool>.Continuation] = [:]
    private init() {}

    func set(_ value: Bool) {
        enabled = value
        subscribers.values.forEach { $0.yield(value) }
    }

    func current() -> Bool { enabled }

    func subscribe() -> (stream: AsyncStream<Bool>, id: UUID) {
        let id = UUID()
        let snapshot = enabled
        var stored: AsyncStream<Bool>.Continuation!
        let stream = AsyncStream<Bool> { cont in
            stored = cont
            cont.yield(snapshot)
        }
        subscribers[id] = stored
        return (stream, id)
    }

    func unsubscribe(_ id: UUID) {
        subscribers[id]?.finish()
        subscribers.removeValue(forKey: id)
    }
}

