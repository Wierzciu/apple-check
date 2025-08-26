import Foundation
import SwiftUI

final class SettingsViewModel: ObservableObject {
    // Instrukcja: Zmień domyślne wartości interwału w minutach poniżej
    @AppStorage("refreshIntervalMinutes") var refreshIntervalMinutes: Int = 15

    @AppStorage("enableDeveloperBeta") var enableDeveloperBeta: Bool = true
    @AppStorage("enablePublicBeta") var enablePublicBeta: Bool = true
    @AppStorage("enableRC") var enableRC: Bool = true
    @AppStorage("enableRelease") var enableRelease: Bool = true

    @AppStorage("notifyDeviceFirst") var notifyDeviceFirst: Bool = true
    @AppStorage("notifyAnnounceFirst") var notifyAnnounceFirst: Bool = true

    @Published private(set) var enabledKinds: Set<OSKind> = Set(OSKind.allCases)

    init() {
        // Można załadować z UserDefaults jeśli potrzebne; uproszczenie – startowo włączone wszystkie
    }

    func set(kind: OSKind, enabled: Bool) {
        if enabled { enabledKinds.insert(kind) } else { enabledKinds.remove(kind) }
    }
}


