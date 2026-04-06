import Elementary

public struct CanvasPage: HTMLDocument {
    public init() {}

    public var title = "Canvas Py"

    public var head: some HTML {
        meta(.charset("UTF-8"))
        meta(.name("viewport"), .content("width=device-width, initial-scale=1.0"))
        script(.src("https://cdn.tailwindcss.com")) {}
    }

    public var body: some HTML {
        div(.class("bg-zinc-900 text-zinc-300 h-screen flex flex-col p-4 gap-3 overflow-hidden")) {
            div(.class("flex items-center gap-3")) {
                #HStack(alignment: .center, spacing: .md) {
                    #Toggle(id: "lockToggle", name: "lockToggle") {
                        #Text(.caption) { "Lock" }
                    }
                    #Toggle(id: "scaledToggle", name: "scaledToggle") {
                        #Text(.caption) { "Scalable" }
                    }
                    #Toggle(id: "kivyToggle", name: "kivyToggle") {
                        #Text(.caption) { "Kivy Mode" }
                    }
                    #Toggle(id: "debugToggle", name: "debugToggle") {
                        #Text(.caption) { "Debug JSON" }
                    }
                    details(.class("relative")) {
                        summary(.class("list-none cursor-pointer text-xs text-zinc-400 hover:text-zinc-200 px-2 py-1 rounded border border-zinc-700 hover:bg-zinc-800 select-none")) {
                            "Smooth ▾"
                        }
                        div(.class("absolute left-0 top-full mt-1 z-50 bg-zinc-800 border border-zinc-700 rounded-lg p-3 flex flex-col gap-2 shadow-xl"), .custom(name: "style", value: "min-width:200px")) {
                            label(.class("flex items-center gap-2 cursor-pointer select-none")) {
                                input(.type(.checkbox), .id("smoothRectangleToggle"), .name("smoothRectangleToggle"))
                                span(.class("text-xs text-zinc-300")) { "SmoothRectangle" }
                            }
                            label(.class("flex items-center gap-2 cursor-pointer select-none")) {
                                input(.type(.checkbox), .id("smoothRoundedRectangleToggle"), .name("smoothRoundedRectangleToggle"), .custom(name: "checked", value: ""))
                                span(.class("text-xs text-zinc-300")) { "SmoothRoundedRectangle" }
                            }
                            label(.class("flex items-center gap-2 cursor-pointer select-none")) {
                                input(.type(.checkbox), .id("smoothEllipseToggle"), .name("smoothEllipseToggle"), .custom(name: "checked", value: ""))
                                span(.class("text-xs text-zinc-300")) { "SmoothEllipse" }
                            }
                            label(.class("flex items-center gap-2 cursor-pointer select-none")) {
                                input(.type(.checkbox), .id("smoothTriangleToggle"), .name("smoothTriangleToggle"), .custom(name: "checked", value: ""))
                                span(.class("text-xs text-zinc-300")) { "SmoothTriangle" }
                            }
                            label(.class("flex items-center gap-2 cursor-pointer select-none")) {
                                input(.type(.checkbox), .id("smoothLineToggle"), .name("smoothLineToggle"), .custom(name: "checked", value: ""))
                                span(.class("text-xs text-zinc-300")) { "SmoothLine" }
                            }
                        }
                    }
                    span(.id("status"), .class("text-xs text-zinc-500 ml-auto")) { "Waiting for selection..." }
                }
            }
            div(.id("editor"), .class("flex-1 rounded-md overflow-hidden min-h-0")) {}
            div(.id("debugView"), .class("flex-1 rounded-md overflow-hidden min-h-0"), .custom(name: "style", value: "display:none")) {}
            div(.id("kivyView"), .class("flex-1 rounded-md overflow-hidden relative min-h-0"), .custom(name: "style", value: "display:none")) {
                iframe(
                    .id("kivyFrame"),
                    .custom(name: "style", value: "width:100%; height:100%; border:none; border-radius:6px; background:#000"),
                    .custom(name: "allowfullscreen", value: ""),
                    .custom(name: "src", value: "about:blank")
                ) {}
                div(.id("kivyOverlay"), .class("absolute inset-0 flex flex-col items-center justify-center gap-3 bg-zinc-900"), .custom(name: "style", value: "display:none")) {
                    #Text(.caption) { "Starting Docker container..." }
                    div(.class("w-48 h-1 bg-zinc-700 rounded-full overflow-hidden")) {
                        div(.id("kivyProgress"), .class("h-full bg-blue-500 rounded-full"), .custom(name: "style", value: "width:0%;transition:width 0.4s")) {}
                    }
                    span(.id("kivyProgressLabel"), .class("text-xs text-zinc-500")) { "Building image (first run may take a few minutes)" }
                }
            }
        }
        script(.src("https://cdn.jsdelivr.net/npm/monaco-editor@0.52.0/min/vs/loader.js")) {}
        script {
            HTMLRaw("""
            const status              = document.getElementById('status');
            const lockToggle          = document.getElementById('lockToggle');
            const scaledToggle        = document.getElementById('scaledToggle');
            const kivyToggle          = document.getElementById('kivyToggle');
            const smoothRectangleToggle        = document.getElementById('smoothRectangleToggle');
            const smoothRoundedRectangleToggle = document.getElementById('smoothRoundedRectangleToggle');
            const smoothEllipseToggle          = document.getElementById('smoothEllipseToggle');
            const smoothLineToggle             = document.getElementById('smoothLineToggle');
            const smoothTriangleToggle         = document.getElementById('smoothTriangleToggle');
            const debugToggle   = document.getElementById('debugToggle');
            const editorEl      = document.getElementById('editor');
            const debugEl       = document.getElementById('debugView');
            const kivyView      = document.getElementById('kivyView');
            const kivyFrame     = document.getElementById('kivyFrame');
            const kivyOverlay   = document.getElementById('kivyOverlay');
            const kivyProgress  = document.getElementById('kivyProgress');
            const kivyLabel     = document.getElementById('kivyProgressLabel');

            // Stable per-tab ID so the server can track kivy subscriptions independently.
            const clientId = Math.random().toString(36).slice(2);

            lockToggle.addEventListener('change', () => {
                fetch('/canvas-py/lock?enabled=' + lockToggle.checked, { method: 'POST' });
                window.parent.postMessage({ type: 'setLock', enabled: lockToggle.checked }, '*');
            });

            // Sync lock toggle across all open browser instances (including background mode).
            const lockStream = new EventSource('/canvas-py/lock-stream');
            lockStream.onmessage = e => {
                const enabled = JSON.parse(e.data);
                lockToggle.checked = enabled;
                // Relay to plugin code.ts so Safari-side lock/unlock reaches Figma.
                window.parent.postMessage({ type: 'setLock', enabled }, '*');
            };

            debugToggle.addEventListener('change', () => {
                if (debugToggle.checked) {
                    editorEl.style.display = 'none';
                    kivyView.style.display = 'none';
                    debugEl.style.display = '';
                    kivyToggle.checked = false;
                    clearTimeout(kivyPollTimer);
                    window.parent.postMessage({ type: 'convert' }, '*');
                } else {
                    debugEl.style.display = 'none';
                    editorEl.style.display = '';
                }
            });

            [smoothRectangleToggle, smoothRoundedRectangleToggle, smoothEllipseToggle, smoothLineToggle, smoothTriangleToggle].forEach(t => t.addEventListener('change', () => {
                window.parent.postMessage({ type: 'convert' }, '*');
            }));

            // ── Kivy Mode ─────────────────────────────────────────────────────
            let kivyPollTimer = null;

            async function pollKivyStatus(attempt) {
                const maxAttempts = 60; // 5 min at 5s intervals
                if (attempt >= maxAttempts) {
                    status.textContent = 'Docker timed out';
                    kivyOverlay.style.display = 'none';
                    return;
                }
                try {
                    const res = await fetch('/canvas-py/kivy-status');
                    const json = await res.json();
                    const pct = Math.min(95, 20 + attempt * 1.5);
                    kivyProgress.style.width = pct + '%';
                    if (json.running && json.url) {
                        kivyProgress.style.width = '100%';
                        kivyLabel.textContent = 'Container ready';
                        setTimeout(() => { kivyOverlay.style.display = 'none'; }, 400);
                        kivyFrame.src = json.url;
                        status.textContent = 'Kivy running';
                        return;
                    }
                } catch(e) {}
                kivyPollTimer = setTimeout(() => pollKivyStatus(attempt + 1), 5000);
            }

            kivyToggle.addEventListener('change', async () => {
                // Tell the server whether this client wants kivy so pushes trigger docker reload.
                fetch('/canvas-py/kivy-register?id=' + clientId + '&enabled=' + kivyToggle.checked, { method: 'POST' });
                if (kivyToggle.checked) {
                    editorEl.style.display = 'none';
                    kivyView.style.display = '';
                    // Check immediately -- container might already be running
                    const res = await fetch('/canvas-py/kivy-status');
                    const json = await res.json();
                    if (json.running && json.url) {
                        kivyFrame.src = json.url;
                        status.textContent = 'Kivy running';
                    } else {
                        kivyOverlay.style.display = '';
                        kivyProgress.style.width = '5%';
                        // If there's a cached code, trigger first push to kick off container build
                        window.parent.postMessage({ type: 'convert' }, '*');
                        pollKivyStatus(0);
                    }
                } else {
                    clearTimeout(kivyPollTimer);
                    kivyView.style.display = 'none';
                    kivyFrame.src = 'about:blank';
                    editorEl.style.display = '';
                    status.textContent = 'Waiting for selection...';
                }
            });

            // Unregister when tab closes so the server stops reloading docker.
            window.addEventListener('beforeunload', () => {
                navigator.sendBeacon('/canvas-py/kivy-register?id=' + clientId + '&enabled=false');
            });

            // ── Monaco ────────────────────────────────────────────────────────
            require.config({ paths: { vs: 'https://cdn.jsdelivr.net/npm/monaco-editor@0.52.0/min/vs' } });
            require(['vs/editor/editor.main'], () => {
                window._editor = monaco.editor.create(document.getElementById('editor'), {
                    value: '# waiting for selection...',
                    language: 'python',
                    theme: 'vs-dark',
                    readOnly: true,
                    minimap: { enabled: false },
                    fontSize: 12,
                    scrollBeyondLastLine: false,
                    automaticLayout: true,
                });
                window._debugEditor = monaco.editor.create(document.getElementById('debugView'), {
                    value: '// waiting for selection...',
                    language: 'json',
                    theme: 'vs-dark',
                    readOnly: true,
                    minimap: { enabled: false },
                    fontSize: 11,
                    scrollBeyondLastLine: false,
                    automaticLayout: true,
                });
            });

            // Subscribe to server-pushed results
            const es = new EventSource('/canvas-py/stream');
            es.onmessage = e => {
                window._editor?.setValue(JSON.parse(e.data));
                if (!kivyToggle.checked) status.textContent = 'Updated.';
            };
            es.onerror = () => { if (!kivyToggle.checked) status.textContent = 'stream error'; };

            // Upload image bytes to the server, then forward figmaNodes for conversion.
            async function uploadImages(images) {
                if (!images?.length) return;
                await Promise.all(images.map(img =>
                    fetch('/image/' + img.hash, {
                        method: 'PUT',
                        headers: { 'Content-Type': 'application/octet-stream' },
                        body: new Uint8Array(img.bytes)
                    })
                ));
            }

            // Extract the first top-level frame's pixel dimensions from serialised nodes JSON.
            function getFrameSize(nodesJson) {
                try {
                    const nodes = JSON.parse(nodesJson);
                    const first = Array.isArray(nodes) ? nodes[0] : null;
                    const bb = first?.absoluteBoundingBox;
                    if (bb) return { width: Math.round(bb.width), height: Math.round(bb.height) };
                } catch(_) {}
                return { width: 0, height: 0 };
            }

            // Forward raw figmaNodes to server — server converts and broadcasts back
            window.addEventListener('message', async e => {
                if (e.data?.type !== 'figmaNodes') return;
                await uploadImages(e.data.images);
                if (debugToggle.checked) {
                    status.textContent = 'Dumping JSON...';
                    fetch('/canvas-py/json-dump', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: e.data.data
                    }).then(r => r.text()).then(txt => {
                        window._debugEditor?.setValue(txt);
                        status.textContent = 'JSON dumped.';
                    }).catch(() => { status.textContent = 'json-dump failed'; });
                    return;
                }
                if (!kivyToggle.checked) status.textContent = 'Converting...';
                const { width, height } = getFrameSize(e.data.data);
                fetch('/canvas-py/push?scalable=' + scaledToggle.checked
                    + '&smoothRectangle=' + smoothRectangleToggle.checked
                    + '&smoothRoundedRectangle=' + smoothRoundedRectangleToggle.checked
                    + '&smoothEllipse=' + smoothEllipseToggle.checked
                    + '&smoothTriangle=' + smoothTriangleToggle.checked
                    + '&smoothLine=' + smoothLineToggle.checked
                    + '&locked=' + lockToggle.checked
                    + '&width=' + width
                    + '&height=' + height, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: e.data.data
                });
            });
            """)
        }
    }
}
