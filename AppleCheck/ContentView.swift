import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var mainVM: MainViewModel
    @EnvironmentObject private var settingsVM: SettingsViewModel
    @State private var didStart = false

    var body: some View {
        NavigationStack {
            List {
                Section("Najnowsze wydania") {
                    ForEach(mainVM.latestReleases) { item in
                        NavigationLink(value: item) {
                            ReleaseRow(item: item)
                        }
                    }
                }
            }
            .navigationTitle("Apple Check")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        mainVM.refreshNow()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .navigationDestination(for: ReleaseItem.self) { item in
                DetailView(kind: item.kind)
            }
            .onAppear {
                guard !didStart else { return }
                didStart = true
                Task { await mainVM.startAutoRefreshIfNeeded(settings: settingsVM) }
            }
        }
    }
}

private struct ReleaseRow: View {
    let item: ReleaseItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.kind.systemImage)
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading) {
                Text(item.displayTitle)
                    .font(.headline)
                Text("Build \(item.build) • \(item.status.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.formattedDate)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}


