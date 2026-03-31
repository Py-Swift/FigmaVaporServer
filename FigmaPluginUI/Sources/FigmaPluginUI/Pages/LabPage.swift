import Elementary

public struct LabPage: HTMLDocument {
    public init() {}

    public var title = "Lab"

    public var head: some HTML {
        meta(.charset("UTF-8"))
        meta(.name("viewport"), .content("width=device-width, initial-scale=1.0"))
        script(.src("https://cdn.tailwindcss.com")) {}
    }

    public var body: some HTML {
        div(.class("bg-zinc-900 text-zinc-300 min-h-screen p-4 text-sm")) {
            #VStack(spacing: .lg) {
                h1(.class("text-white font-semibold tracking-wide")) { "Lab" }
                LabQuickActions()
                LabSendJsPanel()
                LabLogPanel()
            }
        }
        script {
            HTMLRaw("""
            const ws = new WebSocket(`ws://${location.host}/ws`);
            ws.onmessage = e => log(e.data);

            function log(msg) {
                const el = document.getElementById('log');
                el.textContent += '\\n' + msg;
                el.scrollTop = el.scrollHeight;
            }

            function clearLog() {
                document.getElementById('log').textContent = 'Ready.';
            }

            async function doAction(action) {
                const res = await fetch('/lab/action', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ action })
                });
                log(await res.text());
            }

            async function sendJs() {
                const code = document.getElementById('jsInput').value.trim();
                if (!code) return;
                ws.send(JSON.stringify({ type: 'exec', code }));
                log('Sent: ' + code.slice(0, 60));
            }
            """)
        }
    }
}

// MARK: - Sections

struct LabQuickActions: HTML {
    var body: some HTML {
        #Section {
            p(.class("text-xs text-zinc-500 uppercase tracking-wider font-medium")) { "Quick Actions" }
            #HStack(alignment: .center, spacing: .sm, wrap: true) {
                #Button(variant: .secondary, size: .sm, onclick: "doAction('hello')") { "Hello server" }
                #Button(variant: .secondary, size: .sm, onclick: "doAction('ping')") { "Ping" }
                #Button(variant: .ghost, size: .sm, onclick: "doAction('dump-cache')") { "Dump canvas cache" }
            }
        }
    }
}

struct LabSendJsPanel: HTML {
    var body: some HTML {
        #Section {
            p(.class("text-xs text-zinc-500 uppercase tracking-wider font-medium")) { "Send JS to Figma" }
            textarea(
                .id("jsInput"),
                .custom(name: "rows", value: "5"),
                .custom(name: "placeholder", value: "figma.currentPage.selection = [];"),
                .class("w-full bg-zinc-800 text-blue-300 font-mono text-xs rounded-md p-3 border border-zinc-700 focus:outline-none focus:border-zinc-500 resize-y placeholder-zinc-600")
            ) {}
            #Button(variant: .primary, size: .sm, onclick: "sendJs()") { "Send to Figma" }
        }
    }
}

struct LabLogPanel: HTML {
    var body: some HTML {
        #Section {
            #HStack(alignment: .center, spacing: .sm) {
                p(.class("text-xs text-zinc-500 uppercase tracking-wider font-medium flex-1")) { "Log" }
                #Button(variant: .ghost, size: .xs, onclick: "clearLog()") { "clear" }
            }
            pre(
                .id("log"),
                .class("bg-zinc-800 rounded-md p-3 font-mono text-xs text-blue-300 min-h-12 whitespace-pre-wrap break-all")
            ) { "Ready." }
        }
    }
}
