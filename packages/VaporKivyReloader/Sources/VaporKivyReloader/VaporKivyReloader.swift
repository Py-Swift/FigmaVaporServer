import Foundation

// MARK: - KivyReloader

public actor KivyReloader {

    public static let shared = KivyReloader()

    // Navigate from this source file up 4 levels to FigmaVaporServer/, then into figma-kv-preview/
    private let sourceDir: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { url = url.deletingLastPathComponent() }
        return url.appendingPathComponent("figma-kv-preview")
    }()

    private let previewDir = URL(fileURLWithPath: "/tmp/figma-kv-preview")
    private var process: Process?
    private var debounceTask: Task<Void, Never>?

    private init() {}

    // MARK: Public API

    public func reload(kv: String) {
        debounceTask?.cancel()
        debounceTask = Task {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return // cancelled
            }
            do {
                try self.scaffold()
                try self.writeKv(kv)
                try self.launch()
            } catch {
                print("[KivyReloader] error: \(error)")
            }
        }
    }

    // MARK: Private

    private func scaffold() throws {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: previewDir.path) else { return }
        try fm.copyItem(at: sourceDir, to: previewDir)
        print("[KivyReloader] Copied \(sourceDir.lastPathComponent) to \(previewDir.path)")
    }

    private func writeKv(_ kv: String) throws {
        let kvFile = previewDir
            .appendingPathComponent("src")
            .appendingPathComponent("figma_kv_preview")
            .appendingPathComponent("preview.kv")
        try FileManager.default.createDirectory(
            at: kvFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try kv.write(to: kvFile, atomically: true, encoding: .utf8)
        print("[KivyReloader] preview.kv updated")
    }

    private func launch() throws {
        // If process is still running, kivy-reloader watchdog picks up preview.kv change.
        if let proc = process, proc.isRunning { return }

        let uv = resolveUv()
        print("[KivyReloader] Starting: \(uv) run preview")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: uv)
        proc.arguments = ["run", "preview"]
        proc.currentDirectoryURL = previewDir
        proc.standardOutput = FileHandle.standardOutput
        proc.standardError  = FileHandle.standardError
        try proc.run()
        process = proc
        print("[KivyReloader] Kivy app started (PID \(proc.processIdentifier))")
    }

    // MARK: Helpers

    private func resolveUv() -> String {
        if let found = shellWhich("uv") { return found }
        let candidates = [
            "\(NSHomeDirectory())/.local/bin/uv",
            "/usr/local/bin/uv",
            "/opt/homebrew/bin/uv",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) } ?? candidates[0]
    }

    private func shellWhich(_ name: String) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = [name]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }
}
