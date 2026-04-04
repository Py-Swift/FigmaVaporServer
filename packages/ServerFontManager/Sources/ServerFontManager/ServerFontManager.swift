import CoreText
import Foundation

// MARK: - Public API

public enum ServerFontManager {

    /// Resolves font data for a family name. Tries system fonts first, then Google Fonts.
    public static func fontData(for family: String) async -> (data: Data, url: URL)? {
        if let result = systemFont(for: family) { return result }
        return await googleFont(for: family)
    }

    /// All Google Font families baked by the plugin.
    /// Empty until you run: swift package plugin --allow-writing-to-package-directory --allow-network-connections all:443 generate-font-index
    public static var availableFonts: [String] {
        _BakedFonts.fonts.map(\.family).sorted()
    }

    // MARK: - System font (CoreText)

    private static func systemFont(for family: String) -> (data: Data, url: URL)? {
        let attrs = [kCTFontFamilyNameAttribute: family] as CFDictionary
        let desc = CTFontDescriptorCreateWithAttributes(attrs)
        guard
            let matched = CTFontDescriptorCreateMatchingFontDescriptors(desc, nil) as? [CTFontDescriptor],
            let first = matched.first,
            let urlRef = CTFontDescriptorCopyAttribute(first, kCTFontURLAttribute) as? URL,
            let data = try? Data(contentsOf: urlRef)
        else { return nil }
        return (data, urlRef)
    }

    // MARK: - Google Fonts

    private static func googleFont(for family: String) async -> (data: Data, url: URL)? {
        let needle = family.lowercased()
        // Baked index: plugin pre-fetched the TTF URL — no API call needed.
        if let record = _BakedFonts.fonts.first(where: { $0.family.lowercased() == needle }) {
            return await fetchFont(id: record.id, ttfURL: record.ttfURL)
        }
        // Fallback when plugin has not been run: hit gwfh API to get the URL.
        let gwfhId = family.lowercased().replacingOccurrences(of: " ", with: "-")
        return await fetchFontFromGwfh(gwfhId: gwfhId)
    }

    // MARK: - Download helpers

    static let cacheDir: URL = {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ServerFontManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Downloads a font using a URL already known from the baked index.
    private static func fetchFont(id: String, ttfURL: String) async -> (data: Data, url: URL)? {
        let cacheFile = cacheDir.appendingPathComponent("\(id)-regular.ttf")
        if let data = try? Data(contentsOf: cacheFile) { return (data, cacheFile) }
        guard
            let url = URL(string: ttfURL),
            let (data, resp) = try? await URLSession.shared.data(from: url),
            (resp as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        try? data.write(to: cacheFile)
        return (data, cacheFile)
    }

    /// Fallback: asks gwfh API for the TTF URL, then downloads it.
    private static func fetchFontFromGwfh(gwfhId: String) async -> (data: Data, url: URL)? {
        let cacheFile = cacheDir.appendingPathComponent("\(gwfhId)-regular.ttf")
        if let data = try? Data(contentsOf: cacheFile) { return (data, cacheFile) }

        let apiURL = URL(string: "https://gwfh.mranftl.com/api/fonts/\(gwfhId)?subsets=latin")!
        var req = URLRequest(url: apiURL)
        req.setValue("ServerFontManager/1.0", forHTTPHeaderField: "User-Agent")
        guard
            let (apiData, apiResp) = try? await URLSession.shared.data(for: req),
            (apiResp as? HTTPURLResponse)?.statusCode == 200,
            let json = try? JSONSerialization.jsonObject(with: apiData) as? [String: Any],
            let variants = json["variants"] as? [[String: Any]]
        else { return nil }

        let ttfs = variants.compactMap { v -> (id: String, ttf: String)? in
            guard let vid = v["id"] as? String, let ttf = v["ttf"] as? String else { return nil }
            return (vid, ttf)
        }
        guard !ttfs.isEmpty else { return nil }
        let chosen = ttfs.first(where: { $0.id == "regular" }) ?? ttfs[0]

        guard
            let (fontData, fontResp) = try? await URLSession.shared.data(from: URL(string: chosen.ttf)!),
            (fontResp as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        try? fontData.write(to: cacheFile)
        return (fontData, cacheFile)
    }
}
