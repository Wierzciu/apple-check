import Foundation
import SwiftUI
import CoreData

@MainActor
final class MainViewModel: ObservableObject {
    @Published var latestReleases: [ReleaseItem] = []

    private let mergeService = MergeService()
    private let persistence = PersistenceController.shared
    private weak var settingsRef: SettingsViewModel?
    private var autoRefreshTask: Task<Void, Never>?
    private var transitionalRecheckTask: Task<Void, Never>?

    init() {
        // Pierwsze odświeżenie tu, aby UI dostał dane nawet bez interakcji
        Task { [weak self] in
            await self?.refreshAll()
        }
    }

    func refreshNow() {
        Task { await refreshAll() }
    }

    /// Jednorazowe odświeżenie (np. z BGTask)
    func refreshOnce() async {
        await refreshAll()
    }

    func startAutoRefreshIfNeeded(settings: SettingsViewModel) async {
        // Zapamiętujemy referencję do ustawień, aby nie tworzyć nowych instancji
        self.settingsRef = settings
        await refreshAll()
        await BackgroundScheduler.shared.scheduleAppRefresh()
        // Zapobiegamy wielokrotnemu uruchomieniu pętli
        if autoRefreshTask == nil || autoRefreshTask?.isCancelled == true {
            autoRefreshTask = Task { [weak self] in
                guard let self else { return }
                for await _ in TimerSequence.every(minutes: settings.refreshIntervalMinutes) {
                    await self.refreshAll()
                }
            }
        }
    }

    // usunięto runPeriodicRefresh – zastąpione Task w startAutoRefreshIfNeeded

    private func updateUI(after items: [ReleaseItem]) {
        // Najnowsza wersja dla każdego systemu (po numerze wersji ponad kanałami)
        let perKind = sliceBestOverallPerKind(items)
        latestReleases = perKind
            .sorted { a, b in a.kind.displayName < b.kind.displayName }
    }

    private func persist(_ items: [ReleaseItem]) {
        let context = persistence.container.viewContext
        context.perform {
            for item in items { ReleaseRecord.upsert(from: item, in: context) }
            try? context.save()
        }
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
                // Gdy brak ustawień – pokazuj wszystko
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
                    // Dla bet – wybierz większy numer bety
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
                    // Ta sama wersja – priorytet kanałów: dev > public beta > RC > release
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

    // Wybiera lepszą datę publikacji – jeśli jedna wygląda na "nieznaną" (bardzo stara), wybieramy drugą.
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
        // Przekazujemy pełny zestaw, aby updateUI mogło wybrać najlepsze per system
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
        Logger.shared.log("Odświeżanie danych...")
        let items = await fetchAllSources()
        mergeAndPersist(items)
        // Jeżeli są stany przejściowe, uruchamiamy 1-min recheck przez 30 min w tle
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
            // Pobieramy w tle i aktualizujemy UI na głównym aktorze
            let items = await fetchAllSources()
            let hasTransitional = items.contains { $0.status == .device_first || $0.status == .announce_first }
            await MainActor.run { [weak self] in self?.mergeAndPersist(items) }
            if !hasTransitional { break }
        }
        await MainActor.run { [weak self] in self?.transitionalRecheckTask = nil }
    }
}

// Sekwencja timera asynchronicznego co N minut
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


