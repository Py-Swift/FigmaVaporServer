import Vapor
import FigmaTranslator
import KivyCanvasDesigner
import VaporKivyReloader
import Elementary
import VaporElementary
import FigmaPluginUI

struct CanvasRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {

        routes.get("canvas-py") { _ in
            HTMLResponse { CanvasPage() }
        }

        routes.get("canvas-py", "stream") { req -> Response in
            var headers = HTTPHeaders()
            headers.replaceOrAdd(name: .contentType, value: "text/event-stream")
            headers.replaceOrAdd(name: .cacheControl, value: "no-cache")
            headers.replaceOrAdd(name: "X-Accel-Buffering", value: "no")

            let (stream, id) = await CanvasStream.shared.subscribe()
            let loop = req.eventLoop
            let response = Response(headers: headers)
            response.body = .init(stream: { writer in
                Task {
                    for await code in stream {
                        let json = (try? String(decoding: JSONEncoder().encode(code), as: UTF8.self)) ?? "\"\""
                        var buf = ByteBufferAllocator().buffer(capacity: json.utf8.count + 8)
                        buf.writeString("data: \(json)\n\n")
                        loop.execute { writer.write(.buffer(buf), promise: nil) }
                    }
                    loop.execute { writer.write(.end, promise: nil) }
                    await CanvasStream.shared.unsubscribe(id)
                }
            }, count: -1)
            return response
        }

        routes.post("canvas-py") { req -> Response in
            struct Body: Content { var scalable: Bool?; var kivy: Bool?; var smoothRectangle: Bool?; var smoothRoundedRectangle: Bool?; var smoothEllipse: Bool?; var smoothLine: Bool?; var smoothTriangle: Bool?; var nodes: String }
            let body = try req.content.decode(Body.self)
            let nodes = try JSONDecoder().decode([FigmaNode].self, from: Data(body.nodes.utf8))
            let smooth = SmoothOptions(rectangle: body.smoothRectangle ?? false, roundedRectangle: body.smoothRoundedRectangle ?? true, ellipse: body.smoothEllipse ?? true, triangle: body.smoothTriangle ?? true, line: body.smoothLine ?? true)
            let frames = CanvasDesigner.mapToIR(nodes: nodes)
            for (id, svg) in CanvasDesigner.extractSvgs(frames: frames) {
                await SvgStore.shared.store(Data(svg.utf8), for: id)
            }
            let code = CanvasDesigner.generate(frames: frames, scalable: body.scalable ?? false, smooth: smooth)
            await CanvasPyCache.shared.store(code)
            if await CanvasKivyClients.shared.hasAny() { await CanvasReloader.shared.reload(code: code) }
            if await DeviceReloader.shared.isRunning() { await DeviceReloader.shared.reload(code: code) }
            await CanvasStream.shared.broadcast(code)
            return Response(status: .ok, body: .init(string: code))
        }

        routes.post("canvas-py", "push") { req -> Response in
            let scalable                   = (try? req.query.get(Bool.self,   at: "scalable"))                   ?? false
            let smoothRectangle            = (try? req.query.get(Bool.self,   at: "smoothRectangle"))            ?? false
            let smoothRoundedRectangle     = (try? req.query.get(Bool.self,   at: "smoothRoundedRectangle"))     ?? true
            let smoothEllipse              = (try? req.query.get(Bool.self,   at: "smoothEllipse"))              ?? true
            let smoothTriangle             = (try? req.query.get(Bool.self,   at: "smoothTriangle"))             ?? true
            let smoothLine                 = (try? req.query.get(Bool.self,   at: "smoothLine"))                 ?? true
            let locked                     = (try? req.query.get(Bool.self,   at: "locked"))                     ?? false
            let frameWidth                 = (try? req.query.get(Int.self,    at: "width"))                      ?? 0
            let frameHeight                = (try? req.query.get(Int.self,    at: "height"))                     ?? 0
            let nodes = try req.content.decode([FigmaNode].self)
            // Cache raw JSON for debug-export
            if let rawData = req.body.data,
               let rawObj = try? JSONSerialization.jsonObject(with: Data(rawData.readableBytesView)),
               let pretty = try? JSONSerialization.data(withJSONObject: rawObj, options: [.prettyPrinted, .sortedKeys]),
               let prettyStr = String(data: pretty, encoding: .utf8) {
                await CanvasRawJsonCache.shared.store(prettyStr)
            }
            let smooth = SmoothOptions(rectangle: smoothRectangle, roundedRectangle: smoothRoundedRectangle, ellipse: smoothEllipse, triangle: smoothTriangle, line: smoothLine)
            let frames = CanvasDesigner.mapToIR(nodes: nodes)
            let svgPairs = CanvasDesigner.extractSvgs(frames: frames)
            for (id, svg) in svgPairs {
                await SvgStore.shared.store(Data(svg.utf8), for: id)
            }
            let vectorNodeIds = svgPairs.map(\.nodeId)
            var code = CanvasDesigner.generate(frames: frames, scalable: scalable, smooth: smooth)

            // Phase 2: prepend companion .py file when root node is a named page.
            if let rootName = nodes.first?.name,
               let (_, filePath) = FigmaPageFile.parse(rootName),
               await AppContext.shared.hasPyProject,
               let pySource = await AppContext.shared.readPyFile(at: filePath) {
                code = pySource + "\n\n" + code
            }
            await CanvasPyCache.shared.store(code)
            await CanvasStream.shared.broadcast(code)
            if await CanvasKivyClients.shared.hasAny() {
                let sizeChanged = await CanvasWindowSize.shared.update(width: frameWidth, height: frameHeight)
                let action = (locked && !sizeChanged) ? "reload" : "resize+send \(frameWidth)×\(frameHeight)"
                print("[canvas-push] locked=\(locked) \(frameWidth)×\(frameHeight) sizeChanged=\(sizeChanged) → \(action)")
                if locked && !sizeChanged {
                    // Lock on, same size → hot-reload only
                    await CanvasReloader.shared.reload(code: code)
                } else {
                    // Lock off (new selection) or size changed → resize display + send with Window.size
                    await CanvasReloader.shared.restart(code: code, width: frameWidth, height: frameHeight)
                }
            }
            if await DeviceReloader.shared.isRunning() { await DeviceReloader.shared.reload(code: code) }
            // Return vector node IDs so the plugin can export exact SVG strings via exportAsync.
            let idsJSON = (try? String(data: JSONEncoder().encode(vectorNodeIds), encoding: .utf8)) ?? "[]"
            var hdrs = HTTPHeaders(); hdrs.replaceOrAdd(name: .contentType, value: "application/json")
            return Response(status: .ok, headers: hdrs, body: .init(string: "{\"vectorNodeIds\":\(idsJSON)}"))
        }

        routes.post("canvas-py", "json-dump") { req -> Response in
            let bytes = req.body.data ?? ByteBuffer()
            let data = Data(bytes.readableBytesView)
            guard let obj = try? JSONSerialization.jsonObject(with: data),
                  let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
                  let str = String(data: pretty, encoding: .utf8) else {
                return Response(status: .badRequest, body: .init(string: "// invalid json\n"))
            }
            return Response(status: .ok, body: .init(string: str))
        }

        // Register/unregister this client as wanting Kivy mode.
        // id: stable per-tab string   enabled: true/false
        routes.post("canvas-py", "kivy-register") { req -> Response in
            let id      = (try? req.query.get(String.self, at: "id"))   ?? "unknown"
            let enabled = (try? req.query.get(Bool.self,   at: "enabled")) ?? false
            if enabled {
                await CanvasKivyClients.shared.register()
            } else {
                await CanvasKivyClients.shared.unregister()
            }
            return Response(status: .ok)
        }

        routes.get("canvas-py", "kivy-status") { req -> Response in
            struct KivyStatus: Content { var running: Bool; var url: String? }
            let running = await CanvasReloader.shared.isRunning()
            // Return a server-relative URL so only Vapor's port needs to be exposed.
            let url: String? = running
                ? "/vnc-proxy/vnc.html?autoconnect=true&resize=scale&path=websockify"
                : nil
            return try Response(status: .ok, body: .init(data: JSONEncoder().encode(KivyStatus(running: running, url: url))))
        }

        // ── noVNC reverse proxy ───────────────────────────────────────────────
        // Proxies HTTP (static assets) and WebSocket (VNC tunnel) so only
        // port 8765 needs to be reachable — noVNC stays on localhost.

        routes.get("vnc-proxy", .catchall) { req async throws -> Response in
            guard let port = await CanvasReloader.shared.noVncPort() else {
                return Response(status: .serviceUnavailable)
            }
            let path  = req.parameters.getCatchall().joined(separator: "/")
            let query = req.url.query.map { "?\($0)" } ?? ""
            let upstream = URI(string: "http://127.0.0.1:\(port)/\(path)\(query)")
            let clientResp = try await req.client.get(upstream)
            let resp = Response(status: clientResp.status, headers: clientResp.headers)
            if let body = clientResp.body { resp.body = .init(buffer: body) }
            return resp
        }

        routes.webSocket("vnc-proxy", "websockify") { req, clientWs async in
            guard let port = await CanvasReloader.shared.noVncPort() else {
                try? await clientWs.close(code: .unexpectedServerError)
                return
            }
            // Bridge client WebSocket to the local noVNC websockify endpoint.
            // serverWs callbacks are registered on serverWs's event loop (we're already there).
            // clientWs callbacks must be registered on clientWs's event loop — hop to it.
            _ = try? await WebSocket.connect(
                to: "ws://127.0.0.1:\(port)/websockify",
                on: req.application.eventLoopGroup
            ) { serverWs in
                serverWs.onBinary { _, buf in clientWs.send(raw: buf.readableBytesView, opcode: .binary) }
                serverWs.onText  { _, txt in clientWs.send(txt) }
                serverWs.onClose.whenComplete { _ in _ = clientWs.close() }
                clientWs.eventLoop.execute {
                    clientWs.onBinary { _, buf in serverWs.send(raw: buf.readableBytesView, opcode: .binary) }
                    clientWs.onText  { _, txt in serverWs.send(txt) }
                    clientWs.onClose.whenComplete { _ in _ = serverWs.close() }
                }
            }.get()
        }

        routes.get("canvas-py", "display-info") { req -> Response in
            struct DisplayInfo: Content { var requested: String; var xrandr: String }
            let (reqSize, xrandr) = await CanvasReloader.shared.displayInfo()
            return try Response(status: .ok, body: .init(data: JSONEncoder().encode(DisplayInfo(requested: reqSize, xrandr: xrandr))))
        }

        routes.post("canvas-py", "lock") { req -> Response in
            let enabled = (try? req.query.get(Bool.self, at: "enabled")) ?? false
            await CanvasLockState.shared.set(enabled)
            return Response(status: .ok)
        }

        routes.get("canvas-py", "lock-stream") { req -> Response in
            var headers = HTTPHeaders()
            headers.replaceOrAdd(name: .contentType, value: "text/event-stream")
            headers.replaceOrAdd(name: .cacheControl, value: "no-cache")
            headers.replaceOrAdd(name: "X-Accel-Buffering", value: "no")
            let (stream, id) = await CanvasLockState.shared.subscribe()
            let loop = req.eventLoop
            let response = Response(headers: headers)
            response.body = .init(stream: { writer in
                Task {
                    for await enabled in stream {
                        let json = enabled ? "true" : "false"
                        var buf = ByteBufferAllocator().buffer(capacity: 16)
                        buf.writeString("data: \(json)\n\n")
                        loop.execute { writer.write(.buffer(buf), promise: nil) }
                    }
                    loop.execute { writer.write(.end, promise: nil) }
                    await CanvasLockState.shared.unsubscribe(id)
                }
            }, count: -1)
            return response
        }

        routes.get("canvas-py", "last") { req -> Response in
            guard let code = await CanvasPyCache.shared.fetch() else {
                return Response(status: .noContent)
            }
            return Response(status: .ok, body: .init(string: code))
        }

        routes.get("canvas-py", "debug-export") { req -> Response in
            let json   = await CanvasRawJsonCache.shared.fetch() ?? "(no data yet)"
            let python = await CanvasPyCache.shared.fetch()     ?? "(no data yet)"
            let body = """
            json:
            ```
            \(json)
            ```

            python:
            ```
            \(python)
            ```
            """
            var hdrs = HTTPHeaders()
            hdrs.replaceOrAdd(name: .contentType, value: "text/plain; charset=utf-8")
            return Response(status: .ok, headers: hdrs, body: .init(string: body))
        }

        routes.get("status") { req -> Response in
            struct ServerStatus: Content {
                var workingDir: String
                var hasPyProject: Bool
            }
            let status = ServerStatus(
                workingDir:   await AppContext.shared.workingDirectory.path,
                hasPyProject: await AppContext.shared.hasPyProject
            )
            return try Response(status: .ok, body: .init(data: JSONEncoder().encode(status)))
        }
    }
}
