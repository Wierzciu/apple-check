import Foundation

/// Pobieranie informacji z OTA (MESU/SoftwareUpdate). Na start: przykład dla macOS catalog (plist SUCatalog).
struct OtaFetcher {
    func fetchAll() async -> [ReleaseItem] {
        var results: [ReleaseItem] = []
        for url in SourcesRegistry.otaCatalogs {
            if let items = await fetchMacOSCatalog(url: url) { results.append(contentsOf: items) }
        }
        return results
    }

    private func fetchMacOSCatalog(url: URL) async -> [ReleaseItem]? {
        guard let resp = try? await NetworkClient.shared.get(url) else { return [] }
        // SUCatalog to plist zawierający Products -> Build/Version; uproszczony parser:
        guard let plist = try? PropertyListSerialization.propertyList(from: resp.data, options: [], format: nil) as? [String: Any] else { return [] }
        guard let products = plist["Products"] as? [String: Any] else { return [] }
        var items: [ReleaseItem] = []
        for (_, value) in products {
            guard let dict = value as? [String: Any] else { continue }
            // W SUCatalog PostDate bywa stringiem ISO8601 lub Date
            if let anyDate = dict["PostDate"],
               let osVersion = dict["OSVersion"] as? String,
               let build = dict["BuildVersion"] as? String {
                let postDate: Date = {
                    if let d = anyDate as? Date { return d }
                    if let s = anyDate as? String {
                        let iso = ISO8601DateFormatter()
                        return iso.date(from: s) ?? .distantPast
                    }
                    return .distantPast
                }()
                let item = ReleaseItem(kind: .macOS, version: osVersion, build: build, channel: classifyChannel(version: osVersion), publishedAt: postDate, status: .device_first, deviceIdentifier: nil, betaNumber: nil)
                items.append(item)
            }
        }
        return items
    }

    private func classifyChannel(version: String) -> Channel {
        let v = version.lowercased()
        if v.contains("beta") { return .developerBeta }
        if v.contains("rc") { return .rc }
        return .release
    }
}


