import Foundation

/// Registry of sources and discovery rules for channels and major versions.
struct SourcesRegistry {
    /// Developer Releases RSS is always available.
    static let releasesRSS = URL(string: "https://developer.apple.com/news/releases/rss/releases.rss")!
    static let releasesHTML = URL(string: "https://developer.apple.com/news/releases/")!

    /// Example SoftwareUpdate catalog for macOS. Production setups can append more catalogs.
    static let macOSCatalog = URL(string: "https://swscan.apple.com/content/catalogs/others/index-14.sucatalog")!

    /// Add new OTA and web sources by editing the arrays below and extending the relevant fetcher.
    static var otaCatalogs: [URL] { [macOSCatalog] }
    static var wwwCatalogs: [URL] { [releasesRSS, releasesHTML] }

    /// Trusted rumor feeds that often publish expected iOS release timelines.
    static var rumorFeeds: [URL] {
        [
            URL(string: "https://www.macrumors.com/macrumors.xml")!,
            URL(string: "https://9to5mac.com/feed/")!,
            URL(string: "https://appleinsider.com/rss/rumors")!
        ]
    }

    /// Discovers potential major versions based on the highest seen major.
    static func discoverMajors(from versions: [String]) -> Set<Int> {
        let majors = versions.compactMap { Versioning.extractMajor(from: $0) }
        guard let maxMajor = majors.max() else { return [] }
        return [maxMajor, maxMajor + 1, maxMajor + 2]
    }
}
