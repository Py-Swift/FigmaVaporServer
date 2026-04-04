import PackagePlugin
import Foundation

/// SPM command plugin.
///
/// Usage (run once after cloning, or when you want a fresh index):
///
///   cd FigmaVaporServer/ServerFontManager
///   swift package plugin --allow-writing-to-package-directory \
///     --allow-network-connections all:443 \
///     generate-font-index
///
/// Fetches all ~1900 fonts from gwfh.mranftl.com/api/fonts (1 request),
/// then for each font fetches per-font details (TTF/WOFF2 URLs) from
/// gwfh.mranftl.com/api/fonts/{id}?subsets=latin (1 request per font).
/// Writes `Sources/ServerFontManager/GeneratedFontIndex.swift` with the
/// full font metadata baked in — server needs zero network calls at startup.

@main
struct GenerateFontIndex: CommandPlugin {
    func performCommand(context: PluginContext, arguments _: [String]) throws {
        print("GenerateFontIndex: fetching font list from gwfh.mranftl.com…")

        let listData = try syncGet("https://gwfh.mranftl.com/api/fonts")
        guard let fonts = try? JSONSerialization.jsonObject(with: listData) as? [[String: Any]] else {
            let body = String(data: listData, encoding: .utf8) ?? "(binary)"
            print("  Error: unexpected response: \(body.prefix(300))")
            throw PluginError.fetchFailed("unexpected fonts list response")
        }
        print("  Got \(fonts.count) fonts. Fetching per-font details (TTF/WOFF2 URLs)…")

        struct FontRecord {
            let id: String
            let family: String
            let ttfURL: String
            let woff2URL: String
        }

        var records: [FontRecord] = []
        for (i, font) in fonts.enumerated() {
            guard let id = font["id"] as? String,
                  let family = font["family"] as? String else { continue }

            if (i + 1) % 100 == 0 {
                print("  \(i + 1)/\(fonts.count)…")
            }

            guard let detailData = try? syncGet("https://gwfh.mranftl.com/api/fonts/\(id)?subsets=latin"),
                  let detail = try? JSONSerialization.jsonObject(with: detailData) as? [String: Any],
                  let variants = detail["variants"] as? [[String: Any]]
            else { continue }

            let regular = variants.first(where: { ($0["id"] as? String) == "regular" }) ?? variants.first
            guard let v = regular,
                  let ttf = v["ttf"] as? String,
                  let woff2 = v["woff2"] as? String
            else { continue }

            records.append(FontRecord(id: id, family: family, ttfURL: ttf, woff2URL: woff2))
        }

        print("  Collected \(records.count) fonts with URLs.")
        guard !records.isEmpty else { throw PluginError.fetchFailed("no font records") }

        let sorted = records.sorted { $0.id < $1.id }
        let date = ISO8601DateFormatter().string(from: Date())
        var lines: [String] = [
            "// AUTO-GENERATED — do not edit manually.",
            "// Regenerate: swift package plugin --allow-writing-to-package-directory --allow-network-connections all:443 generate-font-index",
            "// Generated: \(date)  (\(sorted.count) fonts from gwfh.mranftl.com)",
            "// swiftformat:disable all",
            "public struct BakedFontRecord: Sendable {",
            "    public let id: String",
            "    public let family: String",
            "    public let ttfURL: String",
            "    public let woff2URL: String",
            "}",
            "public enum _BakedFonts {",
            "    public static let fonts: [BakedFontRecord] = [",
        ]
        for r in sorted {
            let esc = { (s: String) in s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") }
            lines.append("        BakedFontRecord(id: \"\(esc(r.id))\", family: \"\(esc(r.family))\", ttfURL: \"\(esc(r.ttfURL))\", woff2URL: \"\(esc(r.woff2URL))\"),")
        }
        lines.append("    ]")
        lines.append("}")

        let content = lines.joined(separator: "\n") + "\n"
        let outPath = context.package.directory
            .appending(["Sources", "ServerFontManager", "GeneratedFontIndex.swift"])
        try content.write(
            to: URL(fileURLWithPath: outPath.string),
            atomically: true,
            encoding: .utf8
        )
        print("✓ Wrote GeneratedFontIndex.swift with \(sorted.count) fonts (id, family, ttfURL, woff2URL).")
        print("  Rebuild to embed: swift build")
    }

    // MARK: - Synchronous URLSession fetch (network permission applies to this process)

    private func syncGet(_ urlString: String) throws -> Data {
        guard let url = URL(string: urlString) else {
            throw PluginError.fetchFailed("invalid URL: \(urlString)")
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("GenerateFontIndex-Plugin/1.0", forHTTPHeaderField: "User-Agent")

        var result: Result<Data, Error>?
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                result = .failure(error)
            } else if let data, (response as? HTTPURLResponse)?.statusCode == 200 {
                result = .success(data)
            } else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                result = .failure(PluginError.fetchFailed("HTTP \(code) for \(urlString)"))
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()

        switch result! {
        case .success(let data): return data
        case .failure(let error): throw error
        }
    }
}

enum PluginError: Error, CustomStringConvertible {
    case fetchFailed(String)
    var description: String {
        switch self {
        case .fetchFailed(let msg): return "Fetch failed: \(msg)"
        }
    }
}

