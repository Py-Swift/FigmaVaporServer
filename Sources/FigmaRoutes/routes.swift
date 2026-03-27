import Vapor
import Figma2Kv

// Wraps a JS code string into the {type,code} envelope the plugin expects.
private struct ExecCmd: Encodable {
    let type = "exec"
    let code: String
}

private func encodeExec(_ code: String) -> String {
    let data = (try? JSONEncoder().encode(ExecCmd(code: code))) ?? Data()
    return String(decoding: data, as: UTF8.self)
}

public func routes(_ app: Application) throws {
    app.get { _ async in "FigmaVaporServer running." }

    app.post("json-dump") { req -> HTTPStatus in
        guard let body = req.body.string, !body.isEmpty else {
            throw Abort(.badRequest, reason: "Empty body — expected JSON array of Figma nodes.")
        }
        do {
            let nodes = try JSONDecoder().decode([PluginNode].self, from: Data(body.utf8))
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let pretty = try encoder.encode(nodes)
            print(String(decoding: pretty, as: UTF8.self))
        } catch {
            print("Decode error: \(error)")
        }
        return .ok
    }

    app.post("kv") { req -> String in
        guard let body = req.body.string, !body.isEmpty else {
            throw Abort(.badRequest, reason: "Empty body — expected JSON array of Figma nodes.")
        }
        do {
            let nodes = try JSONDecoder().decode([PluginNode].self, from: Data(body.utf8))
            return FigmaMapper.convert(nodes: nodes)
        } catch {
            throw Abort(.unprocessableEntity, reason: "Conversion failed: \(error)")
        }
    }

    // ── WebSocket — persistent connection from the Figma plugin UI ──────────
    app.webSocket("ws") { req, ws in
        await PluginClients.shared.add(ws)
        print("[ws] plugin connected")

        ws.onClose.whenComplete { _ in
            Task { await PluginClients.shared.remove(ws) }
            print("[ws] plugin disconnected")
        }

        // ── Demo sequence — all Figma API logic lives here on the server ────
        Task {
            func send(_ code: String) async {
                guard !ws.isClosed else { return }
                try? await ws.send(encodeExec(code))
            }

            try? await Task.sleep(for: .seconds(1))

            // Create 5 rectangles, one every 2 seconds
            for i in 0..<5 {
                guard !ws.isClosed else { return }
                let x = i * 120
                await send("""
                    const r = figma.createRectangle();
                    r.x = \(x); r.y = -200;
                    r.resize(100, 100);
                    r.name = 'demo-r\(i)';
                    r.fills = [{type:'SOLID',color:{r:0.18,g:0.38,b:1.0}}];
                    figma.currentPage.appendChild(r);
                    tempNodeMap.set('demo-r\(i)', r.id);
                    """)
                try? await Task.sleep(for: .seconds(2))
            }

            // Helper to sweep a colour across all 5 rects with 0.25s delay
            func sweep(r: Double, g: Double, b: Double) async {
                for i in 0..<5 {
                    guard !ws.isClosed else { return }
                    await send("""
                        const id = tempNodeMap.get('demo-r\(i)');
                        const node = id && figma.getNodeById(id);
                        if (node) node.fills = [{type:'SOLID',color:{r:\(r),g:\(g),b:\(b)}}];
                        """)
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }

            // Red sweep left→right
            await sweep(r: 1.0, g: 0.15, b: 0.15)
            try? await Task.sleep(for: .milliseconds(300))

            // Blue sweep left→right
            await sweep(r: 0.15, g: 0.15, b: 1.0)
            try? await Task.sleep(for: .milliseconds(300))

            // Red again
            await sweep(r: 1.0, g: 0.15, b: 0.15)
            try? await Task.sleep(for: .milliseconds(300))

            // Blue again
            await sweep(r: 0.15, g: 0.15, b: 1.0)
            try? await Task.sleep(for: .milliseconds(500))

            // Drop "Demo Complete!!!" text
            guard !ws.isClosed else { return }
            await send("""
                figma.loadFontAsync({family:'Inter',style:'Regular'}).then(() => {
                    const t = figma.createText();
                    t.x = 0; t.y = -330;
                    t.resize(580, 60);
                    t.characters = 'Demo Complete!!!';
                    t.fontSize = 24;
                    t.fills = [{type:'SOLID',color:{r:1,g:1,b:1}}];
                    figma.currentPage.appendChild(t);
                    tempNodeMap.set('demo-txt', t.id);
                });
                """)

            try? await Task.sleep(for: .seconds(2))

            // Clean up everything
            guard !ws.isClosed else { return }
            await send("""
                ['demo-r0','demo-r1','demo-r2','demo-r3','demo-r4','demo-txt'].forEach(tid => {
                    const id = tempNodeMap.get(tid);
                    if (id) { figma.getNodeById(id)?.remove(); tempNodeMap.delete(tid); }
                });
                """)
        }
    }

    // ── Execute arbitrary Figma Plugin API JS on all connected plugins ───────
    // Body: plain JS code string, e.g. "figma.currentPage.selection = [];"
    app.post("command") { req -> HTTPStatus in
        guard let body = req.body.string, !body.isEmpty else {
            throw Abort(.badRequest, reason: "Empty body — expected JS code string.")
        }
        await PluginClients.shared.broadcast(encodeExec(body))
        return .ok
    }
}
