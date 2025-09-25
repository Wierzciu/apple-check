import Foundation

/// Fetches release information from OTA (MESU/SoftwareUpdate) catalogs.
/// Initial implementation covers the macOS SUCatalog plist to showcase the approach.
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
        // SUCatalog is a plist with Products keyed by identifiers containing build/version metadata.
        guard let plist = try? PropertyListSerialization.propertyList(from: resp.data, options: [], format: nil) as? [String: Any] else { return [] }
        guard let products = plist["Products"] as? [String: Any] else { return [] }
        var items: [ReleaseItem] = []
        for (_, value) in products {
            guard let dict = value as? [String: Any] else { continue }
            // PostDate may be a Date or an ISO8601 string.
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
                let item = ReleaseItem(
                    kind: .macOS,
                    version: osVersion,
                    build: build,
                    channel: classifyChannel(version: osVersion),
                    publishedAt: postDate,
                    status: .device_first,
                    deviceIdentifier: nil,
                    betaNumber: nil
                )
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
