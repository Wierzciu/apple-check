import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsVM: SettingsViewModel

    var body: some View {
        Form {
            Section("Odświeżanie") {
                Stepper(value: $settingsVM.refreshIntervalMinutes, in: 1...120, step: 1) {
                    Text("Interwał: \(settingsVM.refreshIntervalMinutes) min")
                }
                Text("Zmiana częstotliwości sprawdzania. BGTask także używa tej wartości.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Kanały") {
                Toggle("Developer Beta", isOn: $settingsVM.enableDeveloperBeta)
                Toggle("Public Beta", isOn: $settingsVM.enablePublicBeta)
                Toggle("RC (Release Candidate)", isOn: $settingsVM.enableRC)
                Toggle("Release (pełne)", isOn: $settingsVM.enableRelease)
                Text("Instrukcja: Aby zmienić domyślnie obsługiwane kanały w kodzie, zobacz plik `Channel.swift`.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Powiadomienia dla stanów przejściowych") {
                Toggle("device_first", isOn: $settingsVM.notifyDeviceFirst)
                Toggle("announce_first", isOn: $settingsVM.notifyAnnounceFirst)
            }

            Section("Systemy") {
                ForEach(OSKind.allCases) { kind in
                    Toggle(kind.displayName, isOn: Binding(
                        get: { settingsVM.enabledKinds.contains(kind) },
                        set: { newValue in
                            settingsVM.set(kind: kind, enabled: newValue)
                        }
                    ))
                }
            }

            Section("Instrukcje") {
                LabeledContent("Nowy katalog/URL") {
                    Text("`Services/Sources.swift` – dodaj nowy wpis lub regułę autodiscovery.")
                }
                LabeledContent("Częstotliwość") {
                    Text("Zmień tutaj lub w `SettingsViewModel.swift` (domyślna wartość)")
                }
                LabeledContent("Kanały") {
                    Text("Włącz/wyłącz powyżej lub zmień domyślne w `Channel.swift`.")
                }
            }
        }
        .navigationTitle("Ustawienia")
    }
}


