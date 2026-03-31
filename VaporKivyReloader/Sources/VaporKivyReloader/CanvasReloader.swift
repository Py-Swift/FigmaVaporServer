import Foundation

// MARK: - CanvasReloader

public actor CanvasReloader {

    public static let shared = CanvasReloader()

    private static let imageName     = "kivy-hot-reload"
    private static let containerName = "kivy-canvas-preview"

    // figma-canvas-preview source dir: 4 levels up from this file → FigmaVaporServer/
    private let sourceDir: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url = url.deletingLastPathComponent() }
        return url.appendingPathComponent("figma-canvas-preview")
    }()

    // kivy-reloader-vscode dir: 5 levels up → figma2kv/
    private let dockerfileDir: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url = url.deletingLastPathComponent() }
        return url.appendingPathComponent("kivy-reloader-vscode")
    }()

    private var deployed = false
    private var debounceTask: Task<Void, Never>?
    private var storedNoVncPort: Int?

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

    /// Stop and remove the container. Resets deployed state so the next reload does full setup.
    public func stop() {
        debounceTask?.cancel()
        debounceTask = nil
        deployed = false
        storedNoVncPort = nil
        guard containerExists() else { return }
        try? run("docker", ["rm", "-f", Self.containerName])
        print("[CanvasReloader] Container stopped and removed.")
    }

    private init() {}

    // MARK: Public API

    public func reload(code: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(200))
            } catch {
                return // cancelled
            }
            do {
                let alreadyDeployed = self.deployed
                try self.ensureSetup(code: code)
                if alreadyDeployed {
                    // Container was running — just update generated.py
                    try self.sendCode(code)
                }
                // If not alreadyDeployed, deployProject() already called sendCode
            } catch {
                print("[CanvasReloader] error: \(error)")
            }
        }
    }

    // MARK: Private — setup

    private func ensureSetup(code: String) throws {
        // 1. Build Docker image if missing
        if !imageExists() {
            print("[CanvasReloader] Docker image '\(Self.imageName)' not found — building (this may take a few minutes)...")
            try buildImage()
        }

        // 2. Start container if not running
        if !containerRunning() {
            if containerExists() {
                try run("docker", ["rm", "-f", Self.containerName])
            }
            print("[CanvasReloader] Starting container '\(Self.containerName)'...")
            // Use empty host port so Docker picks a free port — avoids 'address already in use'
            let result = try run("docker", [
                "run", "-d",
                "--name", Self.containerName,
                "-p", "127.0.0.1::5900",
                "-p", "127.0.0.1::6080",
                Self.imageName
            ])
            guard result == 0, containerRunning() else {
                throw CanvasReloaderError.containerStartFailed
            }
            // Ask Docker which host ports it assigned
            let vncBinding   = (try? capture("docker", ["port", Self.containerName, "5900"])) ?? ""
            let noVncBinding = (try? capture("docker", ["port", Self.containerName, "6080"])) ?? ""
            let vncPort   = vncBinding.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":").last.flatMap { Int($0) } ?? 5900
            let noVncPort = noVncBinding.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":").last.flatMap { Int($0) } ?? 6080
            storedNoVncPort = noVncPort
            print("[CanvasReloader] Container started — VNC: vnc://localhost:\(vncPort)  noVNC: http://localhost:\(noVncPort)/vnc.html")
            // Give VNC/startup script a moment
            Thread.sleep(forTimeInterval: 3)
            try deployProject(code: code)
            deployed = true
        } else if !deployed {
            try deployProject(code: code)
            deployed = true
        }
    }

    private func deployProject(code: String) throws {
        print("[CanvasReloader] Copying project files into container...")
        try run("docker", ["cp", "\(sourceDir.path)/.", "\(Self.containerName):/work/"])
        // Write generated.py into the container
        try sendCode(code)
        // Start the Kivy app
        print("[CanvasReloader] Starting Kivy app inside container...")
        try run("docker", ["exec", "-d", Self.containerName,
            "/bin/bash", "-c", "cd /work && /root/.local/bin/uv run preview"
        ])
        print("[CanvasReloader] Canvas preview running — VNC: http://localhost:6080/vnc.html")
    }

    private func sendCode(_ code: String) throws {
        let tmpFile = URL(fileURLWithPath: "/tmp/figma_canvas_generated.py")
        try code.write(to: tmpFile, atomically: true, encoding: .utf8)
        try run("docker", ["cp", tmpFile.path,
            "\(Self.containerName):/work/src/figma_canvas_preview/generated.py"
        ])
        print("[CanvasReloader] generated.py updated in container")
    }

    // MARK: Private — Docker helpers

    private func buildImage() throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["docker", "build", "--no-cache", "-t", Self.imageName, dockerfileDir.path]
        proc.currentDirectoryURL = dockerfileDir
        proc.standardOutput = FileHandle.standardOutput
        proc.standardError  = FileHandle.standardError
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw CanvasReloaderError.dockerBuildFailed
        }
        print("[CanvasReloader] Docker image '\(Self.imageName)' built successfully")
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
