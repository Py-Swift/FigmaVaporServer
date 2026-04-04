import Foundation

// MARK: - DeviceReloader
//
// Manages the `kivy-device-preview` Docker container.
// The container exposes port 6080 on all interfaces — websockify serves
// noVNC static files AND the WS-to-VNC tunnel on the same plain HTTP/WS port.
// No TLS inside the container; Vapor just starts/stops it and hands the
// browser a direct URL (http://lan-ip:PORT/vnc.html).

public actor DeviceReloader {

    public static let shared = DeviceReloader()

    private static let imageName     = "kivy-device-preview"
    private static let containerName = "kivy-device-preview"

    // workspace root: 5 levels up from this file → figma2kv/
    private let workspaceRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url = url.deletingLastPathComponent() }
        return url
    }()

    private var deployed = false
    private var storedPort: Int?
    private var storedPreviewerPort: Int?
    private var storedLanIP: String = "localhost"
    private var resolution = (width: 390, height: 844)

    // MARK: Public query

    public func isRunning() -> Bool { containerRunning() && storedPort != nil }
    /// URL for the in-browser iframe — always localhost so the page is a secure context.
    public func novncURL() -> String? {
        guard let port = storedPort else { return nil }
        return "http://localhost:\(port)/vnc.html?autoconnect=true&resize=scale"
    }

    public func setLanIP(_ ip: String) {
        storedLanIP = ip
    }

    public func setResolution(width: Int, height: Int) {
        guard width > 0, height > 0 else { return }
        let changed = resolution.width != width || resolution.height != height
        resolution = (width: width, height: height)
        guard changed, containerRunning() else { return }
        let mode = "\(width)x\(height)"
        print("[DeviceReloader] Resizing display to \(mode)...")
        do { try run("docker", ["exec", Self.containerName,
            "/bin/bash", "-c",
            "xrandr --display :99 --fb \(mode) 2>/dev/null; true"
        ]) } catch {}
    }

    public func stop() {
        deployed = false
        storedPort = nil
        storedPreviewerPort = nil
        resolution = (width: 390, height: 844)
        guard containerExists() else { return }
        do { try run("docker", ["rm", "-f", Self.containerName]) } catch {}
        print("[DeviceReloader] Container stopped and removed.")
    }

    private init() {}

    // MARK: Public API

    public func reload(code: String) {
        Task {
            do {
                try await self.ensureSetup()
                try await self.sendCode(code)
            } catch {
                print("[DeviceReloader] error: \(error)")
            }
        }
    }

    // MARK: Private — setup

    private func ensureSetup() async throws {
        if !imageExists() {
            print("[DeviceReloader] Building image '\(Self.imageName)'...")
            try buildImage()
        }

        if !containerRunning() {
            if containerExists() {
                try run("docker", ["rm", "-f", Self.containerName])
            }
            print("[DeviceReloader] Starting container '\(Self.containerName)'...")
            let args = [
                "run", "-d",
                "--name", Self.containerName,
                "-p", "0.0.0.0::6080",
                "-p", "127.0.0.1::7654",
                "-e", "DISPLAY_WIDTH=\(resolution.width)",
                "-e", "DISPLAY_HEIGHT=\(resolution.height)",
                "-e", "FIGMA_SERVER_URL=http://\(storedLanIP):8765",
                "-e", "PYTHONUNBUFFERED=1",
                Self.imageName
            ]
            let result = try run("docker", args)
            guard result == 0, containerRunning() else {
                throw DeviceReloaderError.containerStartFailed
            }
            let noVncBinding = (try? capture("docker", ["port", Self.containerName, "6080"])) ?? ""
            let port = noVncBinding.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: ":").last.flatMap { Int($0) } ?? 6080
            storedPort = port
            let previewerBinding = (try? capture("docker", ["port", Self.containerName, "7654"])) ?? ""
            storedPreviewerPort = previewerBinding.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: ":").last.flatMap { Int($0) }
            deployed = true
            print("[DeviceReloader] Container started — noVNC: http://\(storedLanIP):\(port)/vnc.html")
        } else if !deployed {
            if storedPort == nil {
                let binding = (try? capture("docker", ["port", Self.containerName, "6080"])) ?? ""
                storedPort = binding.trimmingCharacters(in: .whitespacesAndNewlines)
                    .split(separator: ":").last.flatMap { Int($0) }
                if let p = storedPort {
                    print("[DeviceReloader] Reconnected to existing container — noVNC: http://\(storedLanIP):\(p)/vnc.html")
                } else {
                    print("[DeviceReloader] WARNING: could not read port for existing container")
                }
            }
            if storedPreviewerPort == nil {
                let binding = (try? capture("docker", ["port", Self.containerName, "7654"])) ?? ""
                storedPreviewerPort = binding.trimmingCharacters(in: .whitespacesAndNewlines)
                    .split(separator: ":").last.flatMap { Int($0) }
            }
            deployed = true
        }
    }

    private func sendCode(_ code: String) async throws {
        guard let port = storedPreviewerPort else {
            print("[DeviceReloader] No previewer port — skipping send")
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
                print("[DeviceReloader] Canvas code sent to previewer")
                return
            } catch {
                lastError = error
                print("[DeviceReloader] Send attempt \(attempt) failed: \(error) — retrying in \(attempt)s")
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
                          "-f", "kivy-device-preview/Dockerfile",
                          "."]
        proc.currentDirectoryURL = workspaceRoot
        proc.standardOutput = FileHandle.standardOutput
        proc.standardError  = FileHandle.standardError
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { throw DeviceReloaderError.dockerBuildFailed }
        print("[DeviceReloader] Image '\(Self.imageName)' built.")
    }

    private func imageExists() -> Bool {
        let out = try? capture("docker", ["images", "-q", Self.imageName])
        return !(out ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func containerExists() -> Bool {
        let out = try? capture("docker", ["ps", "-a",
            "--filter", "name=^\(Self.containerName)$",
            "--format", "{{.Names}}"
        ])
        return (out ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == Self.containerName
    }

    private func containerRunning() -> Bool {
        let out = try? capture("docker", ["ps",
            "--filter", "name=^\(Self.containerName)$",
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
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }
}

// MARK: - Errors

enum DeviceReloaderError: Error {
    case dockerBuildFailed
    case containerStartFailed
}
