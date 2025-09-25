import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsVM: SettingsViewModel

    var body: some View {
        Form {
            Section("Refresh") {
                Stepper(value: $settingsVM.refreshIntervalMinutes, in: 1...120, step: 1) {
                    Text("Interval: \(settingsVM.refreshIntervalMinutes) min")
                }
                Text("Adjust how frequently Apple Check polls every source. Background tasks reuse this value.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Channels") {
                Toggle("Developer Beta", isOn: $settingsVM.enableDeveloperBeta)
                Toggle("Public Beta", isOn: $settingsVM.enablePublicBeta)
                Toggle("RC (Release Candidate)", isOn: $settingsVM.enableRC)
                Toggle("Release", isOn: $settingsVM.enableRelease)
                Text("Tweak the defaults in `Channel.swift` if you need a different baseline.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Transitional notifications") {
                Toggle("device first", isOn: $settingsVM.notifyDeviceFirst)
                Toggle("announce first", isOn: $settingsVM.notifyAnnounceFirst)
            }

            Section("Platforms") {
                ForEach(OSKind.allCases) { kind in
                    Toggle(kind.displayName, isOn: Binding(
                        get: { settingsVM.enabledKinds.contains(kind) },
                        set: { newValue in
                            settingsVM.set(kind: kind, enabled: newValue)
                        }
                    ))
                }
            }

            Section("Tips") {
                LabeledContent("Add new catalog") {
                    Text("Update `Services/Sources.swift` with the extra entry or discovery rule.")
                }
                LabeledContent("Frequency") {
                    Text("Change it here or adjust the default in `SettingsViewModel.swift`.")
                }
                LabeledContent("Channels") {
                    Text("Toggle above or modify defaults in `Channel.swift`.")
                }
            }
        }
        .navigationTitle("Settings")
    }
}
