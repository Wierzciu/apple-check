import Foundation
import SwiftUI

final class SettingsViewModel: ObservableObject {
    private static let defaultKindsRaw = OSKind.allCases.map(\.rawValue).joined(separator: ",")

    // Instrukcja: Zmień domyślne wartości interwału w minutach poniżej
    @AppStorage("refreshIntervalMinutes") var refreshIntervalMinutes: Int = 15

    @AppStorage("enableDeveloperBeta") var enableDeveloperBeta: Bool = true
    @AppStorage("enablePublicBeta") var enablePublicBeta: Bool = true
    @AppStorage("enableRC") var enableRC: Bool = true
    @AppStorage("enableRelease") var enableRelease: Bool = true

    @AppStorage("notifyDeviceFirst") var notifyDeviceFirst: Bool = true
    @AppStorage("notifyAnnounceFirst") var notifyAnnounceFirst: Bool = true
    @AppStorage("enabledKindsRaw") private var enabledKindsRaw: String = SettingsViewModel.defaultKindsRaw

    @Published private(set) var enabledKinds: Set<OSKind> = []

    init() {
        reloadEnabledKinds()
    }

    func set(kind: OSKind, enabled: Bool) {
        if enabled {
            enabledKinds.insert(kind)
        } else {
            enabledKinds.remove(kind)
        }
        persistEnabledKinds()
    }

    private func reloadEnabledKinds() {
        let stored = enabledKindsRaw
        let components = stored.split(separator: ",").compactMap { OSKind(rawValue: String($0)) }
        if components.isEmpty {
            if stored.isEmpty {
                enabledKinds = []
            } else {
                enabledKinds = Set(OSKind.allCases)
                enabledKindsRaw = SettingsViewModel.defaultKindsRaw
            }
        } else {
            enabledKinds = Set(components)
        }
    }

    private func persistEnabledKinds() {
        let sorted = enabledKinds.sorted { $0.rawValue < $1.rawValue }
        if sorted.isEmpty {
            enabledKindsRaw = ""
        } else {
            enabledKindsRaw = sorted.map(\.rawValue).joined(separator: ",")
        }
    }
}
