import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private override init() { super.init() }

    // Prosta deduplikacja: zapamiętujemy powiadomienia wysłane w ostatnich 60 dniach.
    private let notifiedKey = "notified_ids_v1"
    private let retentionDays: Double = 60

    private func loadNotified() -> [String: TimeInterval] {
        let dict = UserDefaults.standard.dictionary(forKey: notifiedKey) as? [String: TimeInterval]
        return dict ?? [:]
    }

    private func saveNotified(_ dict: [String: TimeInterval]) {
        UserDefaults.standard.set(dict, forKey: notifiedKey)
    }

    private func dedupeKey(for item: ReleaseItem) -> String {
        // Deduplikujemy per (id + status). Dzięki temu „confirmed” może wysłać powiadomienie
        // nawet jeśli wcześniej wysłano „device_first/announce_first”, ale nie powtórzymy
        // wielokrotnie tego samego statusu przy recheck.
        return "\(item.id):\(item.status.rawValue)"
    }

    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            Logger.shared.log("Powiadomienia: \(granted ? "granted" : "denied")")
        }
    }

    func notifyNewRelease(_ item: ReleaseItem) {
        let settings = SettingsViewModel()
        if item.status == .device_first && !settings.notifyDeviceFirst { return }
        if item.status == .announce_first && !settings.notifyAnnounceFirst { return }

        // Deduplikacja
        var dict = loadNotified()
        let key = dedupeKey(for: item)
        let now = Date().timeIntervalSince1970
        let cutoff = now - retentionDays * 24 * 3600
        dict = dict.filter { $0.value >= cutoff }
        if let ts = dict[key], ts >= cutoff { return }
        dict[key] = now
        saveNotified(dict)

        let content = UNMutableNotificationContent()
        content.title = "Nowa wersja: \(item.kind.displayName) \(item.version)"
        content.body = "Build \(item.build) • \(item.channel.displayName) • \(item.status.displayName)"
        let identifier = "\(item.id)-\(item.status.rawValue)"
        let req = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}

