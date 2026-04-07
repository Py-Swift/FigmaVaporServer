import Foundation

// MARK: - CanvasReloader

public actor CanvasReloader {

    public static let shared = CanvasReloader()

    private static let imageName     = "kivy-hot-reload"
    private static let containerName = "kivy-canvas-preview"

    private var deployed = false
    private var storedNoVncPort: Int?
    private var storedPreviewerPort: Int?
    private var resolution = (width: 800, height: 600)

    // MARK: Public query

    public func noVncUrl() -> String? {
        // If we stored the port from when we started the container, use it.
        if let port = storedNoVncPort { return "http://localhost:\(port)/vnc.html?autoconnect=true&resize=scale" }
        // Container may be running from a previous session — ask Docker.
        let out = (try? capture("docker", ["port", Self.containerName, "6080"])) ?? ""
        // output is like '0.0.0.0:6080' or '127.0.0.1:6081'
        if let portStr = out.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":").last,
           let port = Int(portStr) {
            storedNoVncPort = port
            return "http://localhost:\(port)/vnc.html?autoconnect=true&resize=scale"
        }
        return nil
    }

    public func isRunning() -> Bool { containerRunning() }
    public func noVncPort() -> Int? { storedNoVncPort }

    /// Update the virtual display resolution.
    /// If the container is already running, applies the change live via xrandr.
    public func setResolution(width: Int, height: Int) {
        guard width > 0, height > 0 else { return }
        let changed = resolution.width != width || resolution.height != height
        resolution = (width: width, height: height)
        guard changed, containerRunning() else { return }
        let mode = "\(width)x\(height)"
        print("[CanvasReloader] Resizing display to \(mode)...")
        // Add the mode if not present, then switch to it
        do { try run("docker", ["exec", Self.containerName,
            "/bin/bash", "-c",
            "xrandr --display :99 --fb \(mode) 2>/dev/null; true"
        ]) } catch {}
    }

    /// Stop and remove the container. Resets deployed state so the next reload does full setup.
    public func stop() {
        deployed = false
        storedNoVncPort = nil
        storedPreviewerPort = nil
        resolution = (width: 800, height: 600)
        guard containerExists() else { return }
        do { try run("docker", ["rm", "-f", Self.containerName]) } catch {}
        print("[CanvasReloader] Container stopped and removed.")
    }

    private init() {}

    // MARK: Public API

    public func reload(code: String) {
        Task {
            do {
                try await self.ensureSetup()
                print("[CanvasReloader] Hot-reload (\(resolution.width)×\(resolution.height))")
                try await self.sendCode(code)
            } catch {
                print("[CanvasReloader] reload error: \(error)")
            }
        }
    }

    /// Resize the virtual display and send new code with a `Window.size` / `Window.top` / `Window.left`
    /// prepended so the Kivy window matches the Figma frame exactly, centred within the display.
    public func restart(code: String, width: Int, height: Int) {
        let w = width  > 0 ? width  : resolution.width
        let h = height > 0 ? height : resolution.height
        resolution = (width: w, height: h)
        Task {
            do {
                try await self.ensureSetup()
                // Pick the smallest standard monitor resolution that fits the frame.
                let (dispW, dispH) = Self.displayResolution(for: w, h)
                print("[CanvasReloader] frame=\(w)×\(h) → display=\(dispW)×\(dispH)")
                try run("docker", ["exec", Self.containerName,
                    "/bin/bash", "-c",
                    "xrandr --display :99 --fb \(dispW)x\(dispH) 2>/dev/null; true"
                ])
                try await Task.sleep(for: .milliseconds(200))
                // Centre the Kivy window within the display.
                let offsetX = (dispW - w) / 2
                let offsetY = (dispH - h) / 2
                let sizedCode = """
                    from kivy.core.window import Window
                    Window.size = (\(w), \(h))
                    Window.top = \(offsetY)
                    Window.left = \(offsetX)

                    """ + code
                try await self.sendCode(sizedCode)
            } catch {
                print("[CanvasReloader] restart error: \(error)")
            }
        }
    }

    // MARK: - Standard display resolution picker

    private static let standardResolutions: [(Int, Int)] = [
        ( 320,  240),
        ( 640,  480),
        ( 800,  600),
        (1024,  600),
        (1024,  768),
        (1280,  720),
        (1280,  800),
        (1280, 1024),
        (1366,  768),
        (1440,  900),
        (1600,  900),
        (1600, 1024),
        (1920, 1080),
        (1920, 1200),
        (2048, 1080),
        (2048, 1536),
        (2560, 1440),
        (2560, 1600),
        (2560, 2048),
        (3200, 1800),
        (3440, 1440),
        (3840, 2160),
    ]

    /// Smallest standard resolution where dispW >= w AND dispH >= h.
    private static func displayResolution(for w: Int, _ h: Int) -> (Int, Int) {
        standardResolutions.first { $0.0 >= w && $0.1 >= h } ?? (3840, 2160)
    }

    // MARK: Private — setup

    private func ensureSetup() async throws {
        if !imageExists() {
            print("[CanvasReloader] Docker image '\(Self.imageName)' not found — building...")
            try buildImage()
        }

        if !containerRunning() {
            if containerExists() {
                try run("docker", ["rm", "-f", Self.containerName])
            }
            print("[CanvasReloader] Starting container '\(Self.containerName)'...")
            let result = try run("docker", [
                "run", "-d",
                "--name", Self.containerName,
                "-p", "127.0.0.1::5900",
                "-p", "127.0.0.1::6080",
                "-p", "127.0.0.1::7654",
                "-e", "FIGMA_SERVER_URL=http://host.docker.internal:8765",
                "-e", "PYTHONUNBUFFERED=1",
                Self.imageName
            ])
            guard result == 0, containerRunning() else {
                throw CanvasReloaderError.containerStartFailed
            }
            let noVncBinding = (try? capture("docker", ["port", Self.containerName, "6080"])) ?? ""
            storedNoVncPort = noVncBinding.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: ":").last.flatMap { Int($0) } ?? 6080
            let previewerBinding = (try? capture("docker", ["port", Self.containerName, "7654"])) ?? ""
            storedPreviewerPort = previewerBinding.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: ":").last.flatMap { Int($0) }
            deployed = true
            print("[CanvasReloader] Container started — noVNC: http://localhost:\(storedNoVncPort!)/vnc.html")
        } else if !deployed {
            let noVncBinding = (try? capture("docker", ["port", Self.containerName, "6080"])) ?? ""
            storedNoVncPort = noVncBinding.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: ":").last.flatMap { Int($0) }
            let previewerBinding = (try? capture("docker", ["port", Self.containerName, "7654"])) ?? ""
            storedPreviewerPort = previewerBinding.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: ":").last.flatMap { Int($0) }
            deployed = true
        }
    }

    private func sendCode(_ code: String) async throws {
        guard let port = storedPreviewerPort else {
            print("[CanvasReloader] No previewer port — skipping send")
            return
        }
        let url = URL(string: "ws://localhost:\(port)")!
        var lastError: Error? = nil
        for attempt in 1...5 {
            do {
                let task = URLSession.shared.webSocketTask(with: url)
                task.resume()
                try await task.send(.string(code))
                _ = try await task.receive() // wait for 'ok' ack
                task.cancel(with: .normalClosure, reason: nil)
                print("[CanvasReloader] Canvas code sent to previewer")
                return
            } catch {
                lastError = error
                print("[CanvasReloader] Send attempt \(attempt) failed: \(error) — retrying in \(attempt)s")
                try await Task.sleep(for: .seconds(Double(attempt)))
            }
        }
        throw lastError!
    }

    // MARK: Private — Docker helpers

    private func buildImage() throws {
        let fm = FileManager.default
        // Write everything to a self-contained temp directory — no external file dependencies.
        let buildDir = fm.temporaryDirectory.appendingPathComponent("kivy-canvas-build-\(UUID().uuidString)")
        try fm.createDirectory(at: buildDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: buildDir) }

        // 1. Write the embedded Dockerfile.
        try Self.embeddedDockerfile.write(
            to: buildDir.appendingPathComponent("Dockerfile"),
            atomically: true, encoding: .utf8)

        // 2. Write the embedded startup script.
        try Self.embeddedStartScript.write(
            to: buildDir.appendingPathComponent("start-vnc.sh"),
            atomically: true, encoding: .utf8)

        print("[CanvasReloader] Building Docker image '\(Self.imageName)' from temp context…")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["docker", "build", "--no-cache", "-t", Self.imageName, buildDir.path]
        proc.standardOutput = FileHandle.standardOutput
        proc.standardError  = FileHandle.standardError
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw CanvasReloaderError.dockerBuildFailed
        }
        print("[CanvasReloader] Docker image '\(Self.imageName)' built.")
    }

    // MARK: - Embedded Docker assets

    private static let embeddedDockerfile = #"""
FROM python:3.13-slim

RUN apt-get update && apt-get install -y \
    xvfb x11vnc novnc websockify \
    python3-dev libgl1 libgles2 \
    libgstreamer1.0-0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    libmtdev1 libsdl2-2.0-0 libsdl2-image-2.0-0 libsdl2-mixer-2.0-0 libsdl2-ttf-2.0-0 \
    git curl ca-certificates xclip xsel procps \
    x11-xserver-utils fontconfig \
    fonts-noto-core fonts-roboto fonts-open-sans fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

RUN pip install --no-cache-dir kivy pillow websockets

RUN git clone --depth 1 --branch master https://github.com/Py-Swift/figma-kivy-previewer.git /tmp/figma-kivy-previewer \
    && pip install --no-cache-dir /tmp/figma-kivy-previewer \
    && rm -rf /tmp/figma-kivy-previewer

WORKDIR /work

ENV DISPLAY=:99
ENV SDL_VIDEODRIVER=x11
ENV PREVIEWER_IP=0.0.0.0
ENV PREVIEWER_PORT=7654

COPY start-vnc.sh /usr/local/bin/start-vnc.sh
RUN chmod +x /usr/local/bin/start-vnc.sh

EXPOSE 5900 6080 7654
CMD ["/usr/local/bin/start-vnc.sh"]
"""#

    private static let embeddedStartScript = #"""
#!/bin/bash
set -e

rm -f /tmp/.X99-lock /tmp/.X11-unix/X99

echo "Starting Xvfb on display :99 at 3840x2160 (RandR ceiling)..."
Xvfb :99 -screen 0 3840x2160x24 -ac +extension GLX +extension RANDR +render -noreset &
XVFB_PID=$!
sleep 2

echo "Starting x11vnc..."
x11vnc -display :99 -forever -shared -rfbport 5900 -nopw \
    -xkb -ncache 0 -ncache_cr -noxdamage -noxfixes -noxcomposite \
    -skip_lockkeys -speeds lan -wait 5 -defer 5 -progressive 0 -q &
X11VNC_PID=$!
sleep 2

echo "Starting websockify (6080 -> 5900)..."
websockify --web /usr/share/novnc 6080 localhost:5900 &
WEBSOCKIFY_PID=$!

echo "Starting figma-kivy-previewer on port ${PREVIEWER_PORT:-7654}..."
figma-kivy-previewer &
PREVIEWER_PID=$!

cleanup() {
    kill $XVFB_PID $X11VNC_PID $WEBSOCKIFY_PID $PREVIEWER_PID 2>/dev/null || true
    rm -f /tmp/.X99-lock /tmp/.X11-unix/X99
    exit 0
}
trap cleanup EXIT TERM INT
wait -n
exit $?
"""#

    /// Returns the server's requested resolution and the container's live xrandr state.
    /// Hit GET /canvas-py/display-info to see if xrandr accepted the resize.
    /// Note: xrandr --fb can only scale within the Xvfb starting resolution ceiling.
    public func displayInfo() -> (requested: String, xrandr: String) {
        let req = "\(resolution.width)×\(resolution.height)"
        guard containerRunning() else { return (req, "container not running") }
        let xrandr = (try? capture("docker", ["exec", Self.containerName,
            "/bin/bash", "-c", "xrandr --display :99 2>/dev/null | head -6"
        ])) ?? "(xrandr unavailable)"
        return (req, xrandr.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func imageExists() -> Bool {
        let out = try? capture("docker", ["images", "-q", Self.imageName])
        return !(out ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func containerExists() -> Bool {
        let out = try? capture("docker", ["ps", "-a",
            "--filter", "name=\(Self.containerName)",
            "--format", "{{.Names}}"
        ])
        return (out ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == Self.containerName
    }

    private func containerRunning() -> Bool {
        let out = try? capture("docker", ["ps",
            "--filter", "name=\(Self.containerName)",
            "--format", "{{.Names}}"
        ])
        return (out ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == Self.containerName
    }

    @discardableResult
    private func run(_ executable: String, _ args: [String]) throws -> Int32 {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = [executable] + args
        proc.standardOutput = FileHandle.standardOutput
        proc.standardError  = FileHandle.standardError
        try proc.run()
        proc.waitUntilExit()
        return proc.terminationStatus
    }
    private func capture(_ executable: String, _ args: [String]) throws -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = [executable] + args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = FileHandle.nullDevice
        try proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }
}

// MARK: - Errors

enum CanvasReloaderError: Error {
    case dockerBuildFailed
    case containerStartFailed
}
