import Foundation
import CoreData

/// Heuristic forecast of upcoming iOS releases across channels.
/// Rumor integrations should use a dedicated fetcher that merges additional date windows
/// with the historical predictions delivered here.
struct ReleaseForecastService {
    private struct HistoryEntry {
        let version: String
        let channel: Channel
        let date: Date
    }

    private let persistence: PersistenceController
    private let calendar = Calendar(identifier: .gregorian)

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    @MainActor
    func forecastNextIOSReleases(asOf referenceDate: Date = Date(), rumors: [RumorPrediction] = []) -> ReleaseForecastSummary {
        let history = loadHistory(kind: .iOS)
        let orderedChannels: [Channel] = [.developerBeta, .publicBeta, .rc, .release]
        let generatedAt = Date()
        let items = orderedChannels.compactMap { channel -> ReleaseForecast? in
            forecast(for: channel, history: history, asOf: referenceDate, rumors: rumors)
        }
        return .init(kind: .iOS, generatedAt: generatedAt, items: items, rumors: rumors)
    }

    @MainActor
    private func loadHistory(kind: OSKind) -> [HistoryEntry] {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<ReleaseRecord> = ReleaseRecord.fetchRequest()
        request.predicate = NSPredicate(format: "kindRaw == %@ AND publishedAt != nil", kind.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "publishedAt", ascending: true)]
        do {
            let records = try context.fetch(request)
            return records.compactMap { record in
                guard let channel = Channel(rawValue: record.channelRaw),
                      let date = record.publishedAt else { return nil }
                let version = record.version ?? "?"
                return HistoryEntry(version: version, channel: channel, date: date)
            }
        } catch {
            return []
        }
    }

    private func forecast(for channel: Channel, history: [HistoryEntry], asOf referenceDate: Date, rumors: [RumorPrediction]) -> ReleaseForecast? {
        let channelHistory = history.filter { $0.channel == channel }.sorted { $0.date < $1.date }
        guard let latest = channelHistory.last else {
            return makeFallbackForecast(channel: channel, referenceDate: referenceDate, rumors: rumors)
        }
        let intervals = collectIntervals(from: channelHistory)
        if intervals.isEmpty {
            return makeFallbackForecast(channel: channel, referenceDate: latest.date, rumors: rumors)
        }
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        let stdDev = standardDeviation(intervals, average: avgInterval)
        let expectedDate = latest.date.addingTimeInterval(avgInterval * 24 * 3600)
        let toleranceDays = max(2.0, stdDev)
        let window = makeWindow(around: expectedDate, toleranceDays: toleranceDays)
        let confidence: ReleaseForecast.Confidence
        if intervals.count >= 3 && stdDev <= 3 {
            confidence = .high
        } else if intervals.count >= 2 {
            confidence = .medium
        } else {
            confidence = .low
        }
        let formattedExpected = expectedDate.formatted(date: .abbreviated, time: .omitted)
        let avgDays = Int(round(avgInterval))
        var note = "Average of the last \(intervals.count + 1) releases points to \(formattedExpected) (roughly every \(avgDays) days)."
        if channel == .release, let rumorBlurb = earliestRumorBlurb(from: rumors) {
            note += " Rumor spotlight: \(rumorBlurb)"
        }
        return ReleaseForecast(
            id: channel.rawValue,
            channel: channel,
            headline: headline(for: channel),
            note: note,
            window: window,
            confidence: confidence
        )
    }

    private func collectIntervals(from history: [HistoryEntry]) -> [Double] {
        guard history.count >= 2 else { return [] }
        var intervals: [Double] = []
        for idx in 1..<history.count {
            let prev = history[idx - 1].date
            let curr = history[idx].date
            let diff = calendar.dateComponents([.day], from: prev, to: curr).day ?? 0
            if diff > 0 { intervals.append(Double(diff)) }
        }
        return Array(intervals.suffix(4))
    }

    private func standardDeviation(_ values: [Double], average: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let variance = values.reduce(0) { partial, value in
            let delta = value - average
            return partial + delta * delta
        } / Double(values.count)
        return sqrt(variance)
    }

    private func makeWindow(around date: Date, toleranceDays: Double) -> ReleaseForecast.Window {
        let offset = max(1, Int(ceil(toleranceDays)))
        guard let earliest = calendar.date(byAdding: .day, value: -offset, to: date),
              let latest = calendar.date(byAdding: .day, value: offset, to: date) else {
            return .init(earliest: date, latest: date)
        }
        return .init(earliest: earliest, latest: latest)
    }

    private func makeFallbackForecast(channel: Channel, referenceDate: Date, rumors: [RumorPrediction]) -> ReleaseForecast? {
        let fallbackDays: Int
        let confidence: ReleaseForecast.Confidence
        switch channel {
        case .developerBeta:
            fallbackDays = 14
            confidence = .low
        case .publicBeta:
            fallbackDays = 16
            confidence = .low
        case .rc:
            fallbackDays = 21
            confidence = .low
        case .release:
            fallbackDays = 35
            confidence = .low
        }
        guard let baseDate = calendar.date(byAdding: .day, value: fallbackDays, to: referenceDate) else { return nil }
        let window = makeWindow(around: baseDate, toleranceDays: Double(fallbackDays) * 0.2)
        var note = "Not enough history - using a typical spacing of \(fallbackDays) days for the \(channel.displayName) channel."
        if channel == .release, let rumorBlurb = earliestRumorBlurb(from: rumors) {
            note += " Rumor spotlight: \(rumorBlurb)"
        }
        return ReleaseForecast(
            id: channel.rawValue,
            channel: channel,
            headline: headline(for: channel),
            note: note,
            window: window,
            confidence: confidence
        )
    }

    private func earliestRumorBlurb(from rumors: [RumorPrediction]) -> String? {
        let sorted = rumors.compactMap { rumor -> (RumorPrediction, ReleaseForecast.Window)? in
            guard let window = rumor.window else { return nil }
            return (rumor, window)
        }.sorted { lhs, rhs in
            lhs.1.earliest < rhs.1.earliest
        }
        guard let top = sorted.first else { return nil }
        let windowFormatted = top.1.formatted
        return "\(top.0.source) talks about \(windowFormatted)."
    }

    private func headline(for channel: Channel) -> String {
        switch channel {
        case .developerBeta: return "Next developer beta"
        case .publicBeta: return "Next public beta"
        case .rc: return "Release candidate"
        case .release: return "Public release"
        }
    }
}
