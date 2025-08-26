import Foundation

/// Zbiór źródeł oraz reguł autodiscovery dla kanałów i "majorów".
struct SourcesRegistry {
    /// Przykładowe źródła WWW – zawsze działają od razu (RSS Apple Developer Releases)
    static let releasesRSS = URL(string: "https://developer.apple.com/news/releases/rss/releases.rss")!
    static let releasesHTML = URL(string: "https://developer.apple.com/news/releases/")!

    /// Przykładowy katalog SoftwareUpdate dla macOS (OTA, plist). Uwaga: duży plik.
    /// W produkcji można dodać więcej katalogów oraz filtrować po ProductID/Build.
    static let macOSCatalog = URL(string: "https://swscan.apple.com/content/catalogs/others/index-14.sucatalog")!

    /// Instrukcja: Aby dodać nowe źródło OTA/WWW, dodaj URL poniżej oraz obsługę w odpowiednim fetcherze.
    /// - Dodaj OTA (plist/XML/JSON) do `otaCatalogs`
    /// - Dodaj WWW (RSS/HTML) do `wwwCatalogs`
    static var otaCatalogs: [URL] { [macOSCatalog] }
    static var wwwCatalogs: [URL] { [releasesRSS, releasesHTML] }

    /// Autodiscovery nowych "majorów" – na podstawie ostatnio widzianych wersji.
    /// Implementacja przykładowa – generuje listę potencjalnych majorów do sprawdzenia.
    static func discoverMajors(from versions: [String]) -> Set<Int> {
        let majors = versions.compactMap { Versioning.extractMajor(from: $0) }
        guard let maxMajor = majors.max() else { return [] }
        return [maxMajor, maxMajor + 1, maxMajor + 2]
    }
}


