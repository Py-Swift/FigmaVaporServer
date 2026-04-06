import Vapor
import FigmaTranslator
import KivyWidgetDesigner
import KivyCanvasDesigner
import VaporKivyReloader
import Elementary
import VaporElementary
import FigmaPluginUI

struct WidgetRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {

        routes.get("widget-py") { _ in
            HTMLResponse { WidgetPage() }
        }

        routes.get("widget-py", "stream") { req -> Response in
            var headers = HTTPHeaders()
            headers.replaceOrAdd(name: .contentType, value: "text/event-stream")
            headers.replaceOrAdd(name: .cacheControl, value: "no-cache")
            headers.replaceOrAdd(name: "X-Accel-Buffering", value: "no")

            let (stream, id) = await WidgetStream.shared.subscribe()
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
                    await WidgetStream.shared.unsubscribe(id)
                }
            }, count: -1)
            return response
        }

        routes.post("widget-py", "push") { req -> Response in
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
            let smooth = SmoothOptions(rectangle: smoothRectangle, roundedRectangle: smoothRoundedRectangle, ellipse: smoothEllipse, triangle: smoothTriangle, line: smoothLine)
            var code = WidgetDesigner.generate(nodes: nodes, scalable: scalable, smooth: smooth)

            // Phase 2: prepend companion .py file when root node is a named page.
            if let rootName = nodes.first?.name,
               let (_, filePath) = FigmaPageFile.parse(rootName),
               await AppContext.shared.hasPyProject,
               let pySource = await AppContext.shared.readPyFile(at: filePath) {
                code = pySource + "\n\n" + code
            }
            await WidgetPyCache.shared.store(code)
            await WidgetStream.shared.broadcast(code)
            if await WidgetKivyClients.shared.hasAny() {
                let sizeChanged = await WidgetWindowSize.shared.update(width: frameWidth, height: frameHeight)
                let action = (locked && !sizeChanged) ? "reload" : "resize+send \(frameWidth)×\(frameHeight)"
                print("[widget-push] locked=\(locked) \(frameWidth)×\(frameHeight) sizeChanged=\(sizeChanged) → \(action)")
                if locked && !sizeChanged {
                    await CanvasReloader.shared.reload(code: code)
                } else {
                    await CanvasReloader.shared.restart(code: code, width: frameWidth, height: frameHeight)
                }
            }
            if await DeviceReloader.shared.isRunning() { await DeviceReloader.shared.reload(code: code) }
            return Response(status: .ok)
        }

        routes.post("widget-py", "json-dump") { req -> Response in
            let bytes = req.body.data ?? ByteBuffer()
            let data = Data(bytes.readableBytesView)
            guard let obj = try? JSONSerialization.jsonObject(with: data),
                  let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
                  let str = String(data: pretty, encoding: .utf8) else {
                return Response(status: .badRequest, body: .init(string: "// invalid json\n"))
            }
            return Response(status: .ok, body: .init(string: str))
        }

        routes.post("widget-py", "kivy-register") { req -> Response in
            let id      = (try? req.query.get(String.self, at: "id"))      ?? "unknown"
            let enabled = (try? req.query.get(Bool.self,   at: "enabled")) ?? false
            if enabled {
                await WidgetKivyClients.shared.register()
            } else {
                await WidgetKivyClients.shared.unregister()
            }
            return Response(status: .ok)
        }

        routes.get("widget-py", "kivy-status") { req -> Response in
            struct KivyStatus: Content { var running: Bool; var url: String? }
            let running = await CanvasReloader.shared.isRunning()
            let url: String? = running
                ? "/vnc-proxy/vnc.html?autoconnect=true&resize=scale&path=websockify"
                : nil
            return try Response(status: .ok, body: .init(data: JSONEncoder().encode(KivyStatus(running: running, url: url))))
        }

        routes.get("widget-py", "display-info") { req -> Response in
            struct DisplayInfo: Content { var requested: String; var xrandr: String }
            let (reqSize, xrandr) = await CanvasReloader.shared.displayInfo()
            return try Response(status: .ok, body: .init(data: JSONEncoder().encode(DisplayInfo(requested: reqSize, xrandr: xrandr))))
        }

        routes.post("widget-py", "lock") { req -> Response in
            let enabled = (try? req.query.get(Bool.self, at: "enabled")) ?? false
            await WidgetLockState.shared.set(enabled)
            return Response(status: .ok)
        }

        routes.get("widget-py", "lock-stream") { req -> Response in
            var headers = HTTPHeaders()
            headers.replaceOrAdd(name: .contentType, value: "text/event-stream")
            headers.replaceOrAdd(name: .cacheControl, value: "no-cache")
            headers.replaceOrAdd(name: "X-Accel-Buffering", value: "no")
            let (stream, id) = await WidgetLockState.shared.subscribe()
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
                    await WidgetLockState.shared.unsubscribe(id)
                }
            }, count: -1)
            return response
        }

        routes.get("widget-py", "last") { req -> Response in
            guard let code = await WidgetPyCache.shared.fetch() else {
                return Response(status: .noContent)
            }
            return Response(status: .ok, body: .init(string: code))
        }
    }
}
