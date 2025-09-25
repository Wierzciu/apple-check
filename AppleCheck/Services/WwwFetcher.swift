import Foundation

/// Fetches release information from Apple developer-facing websites (RSS/HTML).
struct WwwFetcher {
    func fetchAll() async -> [ReleaseItem] {
        async let rss = fetchFromRSS()
        // HTML parsing is optional for now because the RSS feed typically lists every release.
        let items = await rss
        return items
    }

    /// Parses the developer releases RSS feed at
    /// https://developer.apple.com/news/releases/rss/releases.rss
    private func fetchFromRSS() async -> [ReleaseItem] {
        guard let resp = try? await NetworkClient.shared.get(SourcesRegistry.releasesRSS) else { return [] }
        let parser = SimpleRSSParser()
        let entries = parser.parse(data: resp.data)
        let fallbackHTTPDate: Date? = {
            if let lm = resp.lastModified { return DateFormatter.httpLastModified.date(from: lm) }
            return nil
        }()
        let mapped: [ReleaseItem] = entries.compactMap { entry in
            guard let kind = guessKind(from: entry.title) else { return nil }
            let (version, build, channel, betaNum) = parseTitle(entry.title)
            // Determine publish date precedence: pubDate -> updated -> Last-Modified -> distantPast
            let date = entry.pubDate
                ?? entry.updatedDate
                ?? fallbackHTTPDate
                ?? Date.distantPast
            return ReleaseItem(
                kind: kind,
                version: version,
                build: build,
                channel: channel,
                publishedAt: date,
                status: .announce_first,
                deviceIdentifier: nil,
                betaNumber: betaNum
            )
        }
        return mapped
    }

    /// Maps an RSS title to an OS/Xcode kind.
    private func guessKind(from title: String) -> OSKind? {
        let lower = title.lowercased()
        if lower.contains("xcode") { return .xcode }
        if lower.contains("ios") { return .iOS }
        if lower.contains("ipados") { return .iPadOS }
        if lower.contains("macos") { return .macOS }
        if lower.contains("watchos") { return .watchOS }
        if lower.contains("tvos") { return .tvOS }
        return nil
    }

    /// Extracts the version, build, channel, and optional beta number from the title.
    private func parseTitle(_ title: String) -> (String, String, Channel, Int?) {
        // Sample titles: "iOS 17.5 RC (21F79)", "Xcode 16 beta 2 (16A5171d)", "tvOS 18 (22L123)"
        let build = title.firstMatch(in: #"\(([A-Za-z0-9]+)\)"#) ?? ""
        let channel: Channel
        if title.lowercased().contains("beta") {
            channel = title.lowercased().contains("public beta") ? .publicBeta : .developerBeta
        } else if title.lowercased().contains("rc") {
            channel = .rc
        } else {
            channel = .release
        }
        // Handle versions with and without dots (e.g. "18").
        let version = title.firstMatch(in: #"(\d+(?:\.\d+){0,3})"#) ?? title
        let betaNum = title.firstMatch(in: #"beta\s*(\d+)"#).flatMap { Int($0) }
        return (version, build, channel, betaNum)
    }
}

// Minimal RSS parser based on Foundation.XMLParser
private final class SimpleRSSParser: NSObject, XMLParserDelegate {
    struct Entry { let title: String; let pubDate: Date?; let updatedDate: Date? }
    private var entries: [Entry] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentPubDateString = ""
    private var currentUpdatedString = ""

    func parse(data: Data) -> [Entry] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return entries
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "item" { currentTitle = ""; currentPubDateString = ""; currentUpdatedString = "" }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "title": currentTitle += string
        case "pubDate": currentPubDateString += string
        case "updated": currentUpdatedString += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            let trimmedPub = currentPubDateString.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedUpd = currentUpdatedString.trimmingCharacters(in: .whitespacesAndNewlines)
            let pub = DateFormatter.rfc822Z.date(from: trimmedPub)
                ?? DateFormatter.rfc822zzz.date(from: trimmedPub)
                ?? DateFormatter.iso8601.date(from: trimmedPub)
            let upd = DateFormatter.iso8601.date(from: trimmedUpd)
                ?? DateFormatter.rfc822Z.date(from: trimmedUpd)
                ?? DateFormatter.rfc822zzz.date(from: trimmedUpd)
            entries.append(.init(title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines), pubDate: pub, updatedDate: upd))
        }
        currentElement = ""
    }
}

private extension DateFormatter {
    static let rfc822Z: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return df
    }()
    static let rfc822zzz: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return df
    }()
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let httpLastModified: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss zzz"
        return df
    }()
}

// The String.firstMatch helper lives in `Utils/Versioning.swift`.
