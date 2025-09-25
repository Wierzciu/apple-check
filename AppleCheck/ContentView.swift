import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var mainVM: MainViewModel
    @EnvironmentObject private var settingsVM: SettingsViewModel
    @State private var didStart = false

    var body: some View {
        NavigationStack {
            List {
                if !mainVM.iosForecast.items.isEmpty {
                    Section("iOS Forecast") {
                        ForEach(mainVM.iosForecast.items) { forecast in
                            ForecastRow(forecast: forecast)
                        }
                        Text("Forecast generated \(DisplayDateFormatter.dateTime.string(from: mainVM.iosForecast.generatedAt)).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !mainVM.iosForecast.rumors.isEmpty {
                    Section("Rumor Watch") {
                        ForEach(mainVM.iosForecast.rumors) { rumor in
                            RumorRow(rumor: rumor)
                        }
                    }
                }
                Section("Latest Releases") {
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

private struct ForecastRow: View {
    let forecast: ReleaseForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(forecast.headline)
                    .font(.headline)
                Spacer()
                Text(forecast.window?.formatted ?? "no data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(forecast.note)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Confidence: \(forecast.confidence.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct RumorRow: View {
    let rumor: RumorPrediction

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(rumor.source)
                    .font(.headline)
                Spacer()
                Text(rumor.window?.formatted ?? "no date")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Link(rumor.title, destination: rumor.url)
                .font(.subheadline)
            if !rumor.summary.isEmpty {
                Text(rumor.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text("Confidence: \(rumor.confidence.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
