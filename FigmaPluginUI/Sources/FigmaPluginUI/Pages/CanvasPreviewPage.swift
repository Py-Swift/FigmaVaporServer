import Elementary

public struct CanvasPreviewPage: HTMLDocument {
    public var kivyEnabled: Bool

    public init(kivyEnabled: Bool = false) {
        self.kivyEnabled = kivyEnabled
    }

    public var title = "Canvas Preview"

    public var head: some HTML {
        meta(.charset("UTF-8"))
        meta(.name("viewport"), .content("width=device-width, initial-scale=1.0"))
        script(.src("https://cdn.tailwindcss.com")) {}
    }

    public var body: some HTML {
        div(.class("bg-zinc-900 text-zinc-300 h-screen flex flex-col p-4 gap-3 overflow-hidden")) {
            div(.class("flex items-center gap-3")) {
                #HStack(alignment: .center, spacing: .md) {
                    #Toggle(id: "kivyToggle", name: "kivyToggle", checked: kivyEnabled) {
                        #Text(.caption) { "Kivy Mode" }
                    }
                    #Button(variant: .ghost, size: .xs, onclick: "openBackground()") {
                        "Background"
                    }
                    span(.id("status"), .class("text-xs text-zinc-500 ml-auto")) { "Waiting..." }
                }
            }
            div(.id("editor"), .class("flex-1 rounded-md overflow-hidden min-h-0"),
                .custom(name: "style", value: kivyEnabled ? "display:none" : "")) {}
            div(.id("kivyView"), .class("flex-1 rounded-md overflow-hidden relative min-h-0"),
                .custom(name: "style", value: kivyEnabled ? "" : "display:none")) {
                iframe(
                    .id("kivyFrame"),
                    .custom(name: "style", value: "width:100%; height:100%; border:none; border-radius:6px; background:#000"),
                    .custom(name: "allowfullscreen", value: ""),
                    .custom(name: "src", value: "about:blank")
                ) {}
                div(.id("kivyOverlay"), .class("absolute inset-0 flex flex-col items-center justify-center gap-3 bg-zinc-900"),
                    .custom(name: "style", value: "display:none")) {
                    #Text(.caption) { "Starting Docker container..." }
                    div(.class("w-48 h-1 bg-zinc-700 rounded-full overflow-hidden")) {
                        div(.id("kivyProgress"), .class("h-full bg-blue-500 rounded-full"),
                            .custom(name: "style", value: "width:0%;transition:width 0.4s")) {}
                    }
                    span(.id("kivyProgressLabel"), .class("text-xs text-zinc-500")) {
                        "Building image (first run may take a few minutes)"
                    }
                }
            }
        }
        script(.src("https://cdn.jsdelivr.net/npm/monaco-editor@0.52.0/min/vs/loader.js")) {}
        script {
            HTMLRaw("""
            const status     = document.getElementById('status');
            const kivyToggle = document.getElementById('kivyToggle');
            const editorEl   = document.getElementById('editor');
            const kivyView   = document.getElementById('kivyView');
            const kivyFrame  = document.getElementById('kivyFrame');
            const kivyOverlay  = document.getElementById('kivyOverlay');
            const kivyProgress = document.getElementById('kivyProgress');
            const kivyLabel    = document.getElementById('kivyProgressLabel');

            let kivyPollTimer = null;

            async function pollKivyStatus(attempt) {
                if (attempt >= 60) {
                    status.textContent = 'Docker timed out';
                    kivyOverlay.style.display = 'none';
                    return;
                }
                try {
                    const res = await fetch('/canvas-py/kivy-status');
                    const json = await res.json();
                    kivyProgress.style.width = Math.min(95, 20 + attempt * 1.5) + '%';
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

            async function applyKivy(enabled) {
                // Update server-side setting.
                await fetch('/canvas-preview/settings?kivy=' + enabled, { method: 'POST' });
                if (enabled) {
                    editorEl.style.display = 'none';
                    kivyView.style.display = '';
                    const res = await fetch('/canvas-py/kivy-status');
                    const json = await res.json();
                    if (json.running && json.url) {
                        kivyFrame.src = json.url;
                        status.textContent = 'Kivy running';
                    } else {
                        kivyOverlay.style.display = '';
                        kivyProgress.style.width = '5%';
                        pollKivyStatus(0);
                    }
                } else {
                    clearTimeout(kivyPollTimer);
                    kivyView.style.display = 'none';
                    kivyFrame.src = 'about:blank';
                    editorEl.style.display = '';
                    status.textContent = 'Waiting...';
                }
            }

            kivyToggle.addEventListener('change', () => applyKivy(kivyToggle.checked));

            function openBackground() {
                kivyView.style.display = 'none';
                editorEl.style.display = '';
                status.textContent = 'Running in background';
            }
            // If page loaded with kivy already on, connect immediately.
            if (kivyToggle.checked) {
                fetch('/canvas-py/kivy-status').then(r => r.json()).then(json => {
                    if (json.running && json.url) {
                        kivyFrame.src = json.url;
                        status.textContent = 'Kivy running';
                    } else {
                        kivyOverlay.style.display = '';
                        pollKivyStatus(0);
                    }
                });
            }

            // Monaco for code view.
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
            });

            // Subscribe to server-pushed updates (same stream as the plugin).
            const es = new EventSource('/canvas-py/stream');
            es.onmessage = e => {
                window._editor?.setValue(JSON.parse(e.data));
                if (!kivyToggle.checked) status.textContent = 'Updated.';
            };
            es.onerror = () => { if (!kivyToggle.checked) status.textContent = 'stream error'; };
            """)
        }
    }
}
