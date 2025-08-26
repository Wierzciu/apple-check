import Foundation

/// Scalanie danych z OTA i WWW
struct MergeService {
    // Porównywanie buildów
    func compareBuilds(_ a: String, _ b: String) -> ComparisonResult {
        // Prosty leksykograficzny z drobną normalizacją
        let na = a.replacingOccurrences(of: " ", with: "").lowercased()
        let nb = b.replacingOccurrences(of: " ", with: "").lowercased()
        return na.compare(nb)
    }

    // Normalizacja wersji
    func normalizeVersion(_ s: String) -> String {
        var s = s.lowercased()
        s = s.replacingOccurrences(of: "beta", with: "")
        s = s.replacingOccurrences(of: "rc", with: "")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func merge(wwwItems: [ReleaseItem], otaItems: [ReleaseItem]) -> [ReleaseItem] {
        // Priorytet przy remisie: OTA > WWW
        var map: [String: ReleaseItem] = [:]
        func key(_ item: ReleaseItem) -> String { "\(item.kind.rawValue)-\(normalizeVersion(item.version))" }

        for item in wwwItems {
            let k = key(item)
            if let prev = map[k] {
                // Jeśli build taki sam -> confirmed
                if compareBuilds(prev.build, item.build) == .orderedSame {
                    map[k] = ReleaseItem(kind: item.kind, version: item.version, build: item.build, channel: item.channel, publishedAt: max(item.publishedAt, prev.publishedAt), status: .confirmed, deviceIdentifier: item.deviceIdentifier, betaNumber: item.betaNumber ?? prev.betaNumber)
                } else {
                    // announce_first (WWW ma nowość, OTA jeszcze nie)
                    if prev.status != .device_first { map[k] = item.withStatus(.announce_first) } else { map[k] = prev }
                }
            } else {
                map[k] = item
            }
        }

        for item in otaItems {
            let k = key(item)
            if let prev = map[k] {
                if compareBuilds(prev.build, item.build) == .orderedSame {
                    map[k] = ReleaseItem(kind: item.kind, version: item.version, build: item.build, channel: preferChannel(prev.channel, item.channel), publishedAt: max(item.publishedAt, prev.publishedAt), status: .confirmed, deviceIdentifier: item.deviceIdentifier, betaNumber: item.betaNumber ?? prev.betaNumber)
                } else {
                    // device_first (OTA ma nowość)
                    if prev.status != .announce_first { map[k] = item.withStatus(.device_first) } else { map[k] = prev }
                }
            } else {
                map[k] = item
            }
        }

        return Array(map.values)
    }

    private func preferChannel(_ a: Channel, _ b: Channel) -> Channel {
        // Priorytet: dev > public beta > RC > release
        let order: [Channel: Int] = [.developerBeta: 3, .publicBeta: 2, .rc: 1, .release: 0]
        return (order[a] ?? 0) >= (order[b] ?? 0) ? a : b
    }
}

private extension ReleaseItem {
    func withStatus(_ s: SourceStatus) -> ReleaseItem {
        .init(kind: kind, version: version, build: build, channel: channel, publishedAt: publishedAt, status: s, deviceIdentifier: deviceIdentifier, betaNumber: betaNumber)
    }
}


