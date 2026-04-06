import Foundation

/// Holds working-directory context detected at server startup.
/// Used by routes to resolve companion `.py` files for Figma pages.
public actor AppContext {
    public static let shared = AppContext()

    /// The directory from which the server was launched.
    public let workingDirectory: URL

    /// `true` if a `pyproject.toml` exists in `workingDirectory`.
    public let hasPyProject: Bool

    private init() {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        workingDirectory = cwd
        hasPyProject = FileManager.default.fileExists(
            atPath: cwd.appendingPathComponent("pyproject.toml").path
        )
    }

    /// Reads a `.py` file at `relativePath` relative to the working directory.
    /// Returns `nil` if the file does not exist or cannot be read.
    public func readPyFile(at relativePath: String) -> String? {
        let url = workingDirectory.appendingPathComponent(relativePath)
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

// MARK: - Page name parser

/// Parses a Figma node name of the form `PageName<relative/path.py>`
/// into its page name and relative file path components.
public enum FigmaPageFile {
    /// Returns `(pageName, relativePath)` or `nil` if the name has no embedded `<...py>`.
    public static func parse(_ name: String) -> (pageName: String, filePath: String)? {
        guard name.hasSuffix(">"),
              let open = name.lastIndex(of: "<") else { return nil }
        let filePath = String(name[name.index(after: open)...].dropLast())
        guard filePath.hasSuffix(".py"), !filePath.isEmpty else { return nil }
        let pageName = String(name[..<open]).trimmingCharacters(in: .whitespaces)
        return (pageName, filePath)
    }
}
