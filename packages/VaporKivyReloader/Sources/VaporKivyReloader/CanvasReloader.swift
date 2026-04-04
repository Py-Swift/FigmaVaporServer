import Foundation

// MARK: - CanvasReloader

public actor CanvasReloader {

    public static let shared = CanvasReloader()

    private static let imageName     = "kivy-hot-reload"
    private static let containerName = "kivy-canvas-preview"

    // workspace root: 5 levels up from this file → figma2kv/
    private let workspaceRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url = url.deletingLastPathComponent() }
        return url
    }()

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
                try await self.sendCode(code)
            } catch {
                print("[CanvasReloader] error: \(error)")
            }
        }
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
                "-e", "DISPLAY_WIDTH=\(resolution.width)",
                "-e", "DISPLAY_HEIGHT=\(resolution.height)",
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
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["docker", "build", "--no-cache",
                          "-t", Self.imageName,
                          "-f", "kivy-reloader-vscode/Dockerfile",
                          "."]
        proc.currentDirectoryURL = workspaceRoot
        proc.standardOutput = FileHandle.standardOutput
        proc.standardError  = FileHandle.standardError
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw CanvasReloaderError.dockerBuildFailed
        }
        print("[CanvasReloader] Docker image '\(Self.imageName)' built.")
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
