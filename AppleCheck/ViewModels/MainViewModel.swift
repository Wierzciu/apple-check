import Foundation
import SwiftUI
import CoreData

@MainActor
final class MainViewModel: ObservableObject {
    @Published var latestReleases: [ReleaseItem] = []
    @Published var iosForecast: ReleaseForecastSummary = .emptyIOS

    private let mergeService = MergeService()
    private let persistence = PersistenceController.shared
    private let forecastService = ReleaseForecastService()
    private let rumorFetcher = RumorFetcher()
    private weak var settingsRef: SettingsViewModel?
    private var autoRefreshTask: Task<Void, Never>?
    private var transitionalRecheckTask: Task<Void, Never>?

    init() {
        // Kick off an initial refresh so the UI has data without user interaction.
        Task { [weak self] in
            await self?.refreshAll()
        }
    }

    func refreshNow() {
        Task { await refreshAll() }
    }

    /// Single refresh used by background tasks.
    func refreshOnce() async {
        await refreshAll()
    }

    func startAutoRefreshIfNeeded(settings: SettingsViewModel) async {
        // Keep a reference to SettingsViewModel so we do not spawn new instances.
        self.settingsRef = settings
        await refreshAll()
        BackgroundScheduler.shared.scheduleAppRefresh()
        // Prevent multiple refresh loops from running concurrently.
        if autoRefreshTask == nil || autoRefreshTask?.isCancelled == true {
            autoRefreshTask = Task { [weak self] in
                guard let self else { return }
                for await _ in TimerSequence.every(minutes: settings.refreshIntervalMinutes) {
                    await self.refreshAll()
                }
            }
        }
    }

    // runPeriodicRefresh replaced by Task in startAutoRefreshIfNeeded.

    private func updateUI(after items: [ReleaseItem]) {
        // Latest version per platform, prioritising version numbers over channels.
        let perKind = sliceBestOverallPerKind(items)
        latestReleases = perKind
            .sorted { a, b in a.kind.displayName < b.kind.displayName }
    }

    private func persist(_ items: [ReleaseItem]) {
        let context = persistence.container.viewContext
        context.perform { [weak self] in
            for item in items { ReleaseRecord.upsert(from: item, in: context) }
            try? context.save()
            Task { [weak self] in await self?.refreshIOSForecast() }
        }
    }

    @MainActor
    private func refreshIOSForecast() async {
        let rumors = await rumorFetcher.fetchIOSRumors()
        iosForecast = forecastService.forecastNextIOSReleases(rumors: rumors)
    }

    private func notifyNewConfirmed(_ items: [ReleaseItem]) {
        for item in items where item.status == .confirmed || item.status == .device_first || item.status == .announce_first {
            NotificationManager.shared.notifyNewRelease(item)
        }
    }

    private func filterBySettings(_ items: [ReleaseItem]) -> [ReleaseItem] {
        let settings = settingsRef
        return items.filter { item in
            if let settings {
                guard settings.enabledKinds.contains(item.kind) else { return false }
                switch item.channel {
                case .developerBeta: return settings.enableDeveloperBeta
                case .publicBeta: return settings.enablePublicBeta
                case .rc: return settings.enableRC
                case .release: return settings.enableRelease
                }
            } else {
                // When no settings are provided show everything.
                return true
            }
        }
    }

    private func sliceLatestPerKind(_ items: [ReleaseItem]) -> [ReleaseItem] {
        var map: [OSKind: ReleaseItem] = [:]
        for item in items {
            if let existing = map[item.kind] {
                if item.publishedAt > existing.publishedAt { map[item.kind] = item }
            } else {
                map[item.kind] = item
            }
        }
        return Array(map.values)
    }

    private func sliceLatestByVersion(_ items: [ReleaseItem]) -> [ReleaseItem] {
        var map: [OSKind: ReleaseItem] = [:]
        for item in items {
            if let existing = map[item.kind] {
                let cmp = Versioning.compareVersions(item.version, existing.version)
                if cmp == .orderedDescending { map[item.kind] = item }
            } else { map[item.kind] = item }
        }
        return Array(map.values)
    }

    private func sliceLatestByVariant(_ items: [ReleaseItem]) -> [ReleaseItem] {
        struct Key: Hashable { let kind: OSKind; let channel: Channel }
        var map: [Key: ReleaseItem] = [:]
        for item in items {
            let key = Key(kind: item.kind, channel: item.channel)
            if let existing = map[key] {
                let cmp = Versioning.compareVersions(item.version, existing.version)
                if cmp == .orderedDescending {
                    map[key] = item
                } else if cmp == .orderedSame {
                    // For betas, prefer the higher beta counter.
                    if let b1 = item.betaNumber, let b2 = existing.betaNumber, b1 > b2 { map[key] = item }
                    else if existing.betaNumber == nil, item.betaNumber != nil { map[key] = item }
                }
            } else {
                map[key] = item
            }
        }
        return Array(map.values)
    }

    private func sliceBestOverallPerKind(_ items: [ReleaseItem]) -> [ReleaseItem] {
        var map: [OSKind: ReleaseItem] = [:]
        for item in items {
            if let existing = map[item.kind] {
                let cmp = Versioning.compareVersions(item.version, existing.version)
                if cmp == .orderedDescending {
                    map[item.kind] = item.withPublishedAt(bestPublishedDate(item.publishedAt, existing.publishedAt))
                } else if cmp == .orderedSame {
                    // Same version: ranking developer beta > public beta > RC > release.
                    let rank: [Channel: Int] = [.developerBeta: 3, .publicBeta: 2, .rc: 1, .release: 0]
                    let rNew = rank[item.channel] ?? 0
                    let rOld = rank[existing.channel] ?? 0
                    if rNew != rOld {
                        if rNew > rOld { map[item.kind] = item.withPublishedAt(bestPublishedDate(item.publishedAt, existing.publishedAt)) }
                    } else {
                        let bNew = item.betaNumber ?? -1
                        let bOld = existing.betaNumber ?? -1
                        if bNew > bOld { map[item.kind] = item.withPublishedAt(bestPublishedDate(item.publishedAt, existing.publishedAt)) }
                    }
                }
            } else {
                map[item.kind] = item
            }
        }
        return Array(map.values)
    }

    // Resolve questionable publish dates by preferring the more plausible value.
    private func bestPublishedDate(_ a: Date, _ b: Date) -> Date {
        let thresholdComponents = DateComponents(calendar: Calendar(identifier: .gregorian), year: 2002, month: 1, day: 1)
        let threshold = thresholdComponents.date ?? Date(timeIntervalSince1970: 0)
        let aUnknown = a < threshold
        let bUnknown = b < threshold
        if aUnknown && !bUnknown { return b }
        if bUnknown && !aUnknown { return a }
        return max(a, b)
    }

    private func mergeAndPersist(_ sourceItems: [ReleaseItem]) {
        let filtered = filterBySettings(sourceItems)
        // Pass the full set so updateUI can pick the strongest entries per platform.
        updateUI(after: filtered)
        persist(filtered)
        notifyNewConfirmed(filtered)
    }

    private func fetchAllSources() async -> [ReleaseItem] {
        async let www = WwwFetcher().fetchAll()
        async let ota = OtaFetcher().fetchAll()
        let (wwwItems, otaItems) = await (www, ota)
        return mergeService.merge(wwwItems: wwwItems, otaItems: otaItems)
    }

    private func refreshAll() async {
        Logger.shared.log("Refreshing data...")
        let items = await fetchAllSources()
        mergeAndPersist(items)
        // If transitional states exist, launch a 1-minute recheck loop for up to 30 minutes.
        let transitional = items.contains { $0.status == .device_first || $0.status == .announce_first }
        if transitional {
            if transitionalRecheckTask == nil || transitionalRecheckTask?.isCancelled == true {
                transitionalRecheckTask = Task.detached { [weak self] in
                    await self?.recheckTransitionalStates(minutes: 1, attempts: 30)
                }
            }
        }
    }

    private func recheckTransitionalStates(minutes: Int, attempts: Int) async {
        for i in 0..<attempts {
            if Task.isCancelled { break }
            Logger.shared.log("Recheck (\(i+1)/\(attempts))")
            try? await Task.sleep(nanoseconds: UInt64(minutes * 60) * 1_000_000_000)
            // Fetch on a background task and update the UI on the main actor.
            let items = await fetchAllSources()
            let hasTransitional = items.contains { $0.status == .device_first || $0.status == .announce_first }
            await MainActor.run { [weak self] in self?.mergeAndPersist(items) }
            if !hasTransitional { break }
        }
        await MainActor.run { [weak self] in self?.transitionalRecheckTask = nil }
    }
}

// Async timer sequence that ticks every N minutes.
struct TimerSequence: AsyncSequence {
    typealias Element = Void
    struct AsyncIterator: AsyncIteratorProtocol {
        let interval: TimeInterval
        mutating func next() async -> Void? {
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            return ()
        }
    }
    let interval: TimeInterval
    func makeAsyncIterator() -> AsyncIterator { .init(interval: interval) }

    static func every(minutes: Int) -> TimerSequence { .init(interval: TimeInterval(minutes * 60)) }
}
