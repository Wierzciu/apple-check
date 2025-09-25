import Foundation

/// Merges OTA and web sourced releases into a coherent timeline.
struct MergeService {
    // Build comparison with simple normalization.
    func compareBuilds(_ a: String, _ b: String) -> ComparisonResult {
        let na = a.replacingOccurrences(of: " ", with: "").lowercased()
        let nb = b.replacingOccurrences(of: " ", with: "").lowercased()
        return na.compare(nb)
    }

    // Normalise versions for hash keys.
    func normalizeVersion(_ s: String) -> String {
        var s = s.lowercased()
        s = s.replacingOccurrences(of: "beta", with: "")
        s = s.replacingOccurrences(of: "rc", with: "")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func merge(wwwItems: [ReleaseItem], otaItems: [ReleaseItem]) -> [ReleaseItem] {
        // If entries collide, OTA wins.
        var map: [String: ReleaseItem] = [:]
        func key(_ item: ReleaseItem) -> String { "\(item.kind.rawValue)-\(normalizeVersion(item.version))" }

        for item in wwwItems {
            let k = key(item)
            if let prev = map[k] {
                // Same build means the release is confirmed.
                if compareBuilds(prev.build, item.build) == .orderedSame {
                    map[k] = ReleaseItem(
                        kind: item.kind,
                        version: item.version,
                        build: item.build,
                        channel: item.channel,
                        publishedAt: max(item.publishedAt, prev.publishedAt),
                        status: .confirmed,
                        deviceIdentifier: item.deviceIdentifier,
                        betaNumber: item.betaNumber ?? prev.betaNumber
                    )
                } else {
                    // Web sources announced the build before OTA.
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
                    map[k] = ReleaseItem(
                        kind: item.kind,
                        version: item.version,
                        build: item.build,
                        channel: preferChannel(prev.channel, item.channel),
                        publishedAt: max(item.publishedAt, prev.publishedAt),
                        status: .confirmed,
                        deviceIdentifier: item.deviceIdentifier,
                        betaNumber: item.betaNumber ?? prev.betaNumber
                    )
                } else {
                    // OTA saw the build first.
                    if prev.status != .announce_first { map[k] = item.withStatus(.device_first) } else { map[k] = prev }
                }
            } else {
                map[k] = item
            }
        }

        return Array(map.values)
    }

    private func preferChannel(_ a: Channel, _ b: Channel) -> Channel {
        // Channel priority: developer beta > public beta > RC > release.
        let order: [Channel: Int] = [.developerBeta: 3, .publicBeta: 2, .rc: 1, .release: 0]
        return (order[a] ?? 0) >= (order[b] ?? 0) ? a : b
    }
}

private extension ReleaseItem {
    func withStatus(_ s: SourceStatus) -> ReleaseItem {
        .init(
            kind: kind,
            version: version,
            build: build,
            channel: channel,
            publishedAt: publishedAt,
            status: s,
            deviceIdentifier: deviceIdentifier,
            betaNumber: betaNumber
        )
    }
}
