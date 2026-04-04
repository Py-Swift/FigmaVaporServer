import Foundation

/// Announces the server on the local network via Bonjour using the macOS
/// built-in `dns-sd` command. No extra frameworks or packages needed.
///
/// Service type: `_figmakv._tcp`  — browsed by the FigmaKvDevice iOS app.
public final class BonjourAnnouncer: @unchecked Sendable {
    public static let shared = BonjourAnnouncer()

    private var process: Process?

    private init() {}

    public func start(port: Int = 8765) {
        guard process == nil else { return }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/dns-sd")
        // -R name type domain port [TXT key=val ...]
        p.arguments = ["-R", "FigmaVaporServer", "_figmakv._tcp", "local", "\(port)"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError  = FileHandle.nullDevice

        do {
            try p.run()
            process = p
            print("[Bonjour] Announcing _figmakv._tcp on port \(port)")
        } catch {
            print("[Bonjour] Failed to start dns-sd: \(error)")
        }
    }

    deinit {
        process?.terminate()
    }
}
