import Foundation

/// Fetches rumor-based predictions from trusted publications.
struct RumorFetcher {
    private let network = NetworkClient.shared
    private let calendar = Calendar(identifier: .gregorian)
    private let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

    func fetchIOSRumors(referenceDate: Date = Date()) async -> [RumorPrediction] {
        await withTaskGroup(of: [RumorPrediction].self) { group -> [RumorPrediction] in
            for url in SourcesRegistry.rumorFeeds {
                group.addTask {
                    await fetchRumors(from: url, referenceDate: referenceDate)
                }
            }
            var combined: [RumorPrediction] = []
            for await predictions in group { combined.append(contentsOf: predictions) }
            let deduped = deduplicate(combined)
            return deduped.sorted { lhs, rhs in
                let lDate = lhs.window?.earliest ?? .distantFuture
                let rDate = rhs.window?.earliest ?? .distantFuture
                if lDate == rDate { return lhs.title < rhs.title }
                return lDate < rDate
            }
        }
    }

    private func fetchRumors(from url: URL, referenceDate: Date) async -> [RumorPrediction] {
        guard let response = try? await network.get(url) else { return [] }
        let parser = RSSParser()
        let entries = parser.parse(data: response.data)
        let domain = url.host ?? ""
        return entries.compactMap { entry in
            guard shouldConsider(entry: entry) else { return nil }
            let window = detectWindow(in: entry, referenceDate: referenceDate)
            guard window != nil else { return nil }
            let confidence = confidenceForDomain(domain)
            let summary = sanitize(entry.summary)
            return RumorPrediction(
                id: entry.link?.absoluteString ?? UUID().uuidString,
                source: readableSourceName(from: domain),
                title: entry.title,
                summary: summary,
                url: entry.link ?? url,
                window: window,
                confidence: confidence
            )
        }
    }

    private func shouldConsider(entry: RSSParser.Entry) -> Bool {
        let lowerTitle = entry.title.lowercased()
        let lowerSummary = entry.summary.lowercased()
        let keywords = ["ios", "iphone", "beta", "release", "launch"]
        return keywords.contains(where: { lowerTitle.contains($0) || lowerSummary.contains($0) })
    }

    private func detectWindow(in entry: RSSParser.Entry, referenceDate: Date) -> ReleaseForecast.Window? {
        guard let detector else { return nil }
        let text = entry.title + " " + entry.summary
        let range = NSRange(location: 0, length: (text as NSString).length)
        let matches = detector.matches(in: text, options: [], range: range)
        let futureMatches = matches.compactMap { result -> Date? in
            guard let date = result.date else { return nil }
            // Ignore past dates beyond 12 hours.
            if date < referenceDate.addingTimeInterval(-12 * 3600) { return nil }
            // Ignore dates beyond six months.
            if date > referenceDate.addingTimeInterval(180 * 24 * 3600) { return nil }
            return date
        }
        guard let target = futureMatches.first else { return nil }
        let earliest = calendar.date(byAdding: .day, value: -1, to: target) ?? target
        let latest = calendar.date(byAdding: .day, value: 1, to: target) ?? target
        return ReleaseForecast.Window(earliest: earliest, latest: latest)
    }

    private func readableSourceName(from domain: String) -> String {
        if domain.contains("macrumors") { return "MacRumors" }
        if domain.contains("9to5mac") { return "9to5Mac" }
        if domain.contains("appleinsider") { return "AppleInsider" }
        return domain.isEmpty ? "Unknown" : domain
    }

    private func confidenceForDomain(_ domain: String) -> ReleaseForecast.Confidence {
        if domain.contains("appleinsider") { return .medium }
        if domain.contains("macrumors") { return .medium }
        if domain.contains("9to5mac") { return .low }
        return .low
    }

    private func sanitize(_ text: String) -> String {
        let cleaned = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if cleaned.count > 240 {
            let endIndex = cleaned.index(cleaned.startIndex, offsetBy: 240)
            return String(cleaned[..<endIndex]) + "..."
        }
        return cleaned
    }

    private func deduplicate(_ predictions: [RumorPrediction]) -> [RumorPrediction] {
        var seen: Set<String> = []
        var result: [RumorPrediction] = []
        for item in predictions {
            let key = item.title.lowercased() + (item.window?.formatted ?? "")
            if seen.insert(key).inserted { result.append(item) }
        }
        return result
    }
}

private final class RSSParser: NSObject, XMLParserDelegate {
    struct Entry {
        let title: String
        let summary: String
        let link: URL?
    }

    private var entries: [Entry] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentSummary = ""
    private var currentLinkString = ""

    func parse(data: Data) -> [Entry] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return entries
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "item" || elementName == "entry" {
            currentTitle = ""
            currentSummary = ""
            currentLinkString = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "title": currentTitle += string
        case "description", "summary": currentSummary += string
        case "link": currentLinkString += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" || elementName == "entry" {
            let trimmedTitle = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedSummary = currentSummary.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLink = currentLinkString.trimmingCharacters(in: .whitespacesAndNewlines)
            let link = URL(string: trimmedLink)
            entries.append(.init(title: trimmedTitle, summary: trimmedSummary, link: link))
        }
        currentElement = ""
    }
}
