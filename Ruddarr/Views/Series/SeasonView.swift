import SwiftUI
import TelemetryDeck

struct SeasonView: View {
    @Binding var series: Series
    var seasonId: Season.ID

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) var instance

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                header
                    .padding(.bottom)

                actions
                    .padding(.bottom)

                episodesList
            }
            .viewPadding(.horizontal)
        }
        .refreshable {
            await Task { await reload() }.value
        }
        .toolbar {
            toolbarMonitorButton
        }
        .task {
            await instance.episodes.maybeFetch(series)
            await instance.files.maybeFetch(series)
        }
        .alert(
            isPresented: instance.episodes.errorBinding,
            error: instance.episodes.error
        ) { _ in
            Button("OK") { instance.episodes.error = nil }
        } message: { error in
            Text(error.recoverySuggestionFallback)
        }
    }

    var season: Season {
        series.seasonById(seasonId)!
    }

    var episodes: [Episode] {
        instance.episodes.items
            .filter { $0.seasonNumber == seasonId }
            .sorted { $0.episodeNumber > $1.episodeNumber }
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(series.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 250, alignment: .leading)
                .offset(y: 2)

            Text(season.label)
                .font(.largeTitle.bold())

            HStack(spacing: 6) {
                Text(year)

                if let minutes = runtime {
                    Bullet()
                    Text(formatRuntime(minutes))
                }

                if let bytes = season.statistics?.sizeOnDisk, bytes > 0 {
                    Bullet()
                    Text(formatBytes(bytes))
                }
            }
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var year: String {
        let episode = episodes
            .filter { $0.airDateUtc != nil }
            .min(by: { $0.airDateUtc! < $1.airDateUtc! })

        if let date = episode?.airDateUtc {
            return String(Calendar.current.component(.year, from: date))
        }

        return String(localized: "TBA")
    }

    var runtime: Int? {
        let items = episodes.map { $0.runtime ?? 0 }.filter { $0 > 0 }
        guard !items.isEmpty else { return nil }
        return items.sorted(by: <)[items.count / 2]
    }

    var actions: some View {
        HStack(spacing: 24) {
            Button {
                Task { await dispatchSearch() }
            } label: {
                ButtonLabel(text: "Automatic", icon: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .allowsHitTesting(!instance.series.isWorking)

            NavigationLink(
                value: SeriesPath.releases(series.id, seasonId, nil)
            ) {
                ButtonLabel(text: "Interactive", icon: "person.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 450)
    }

    var episodesList: some View {
        Section {
            if instance.episodes.isFetching {
                HStack {
                    Spacer()
                    ProgressView().tint(.secondary)
                    Spacer()
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(episodes) { episode in
                        NavigationLink(
                            value: SeriesPath.episode(episode.seriesId, episode.id)
                        ) {
                            EpisodeRow(episode: episode)
                                .environment(instance)
                                .environmentObject(settings)
                        }
                        .buttonStyle(.plain)

                        Divider()
                    }
                }
            }
        } header: {
            Text("Episodes").font(.title2.bold()).padding(.bottom, 6)
        }
    }

    @ToolbarContentBuilder
    var toolbarMonitorButton: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                Task { await toggleMonitor() }
            } label: {
                ToolbarMonitorButton(monitored: .constant(season.monitored))
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!instance.series.isWorking)
            .disabled(!series.monitored)
            .id(UUID())
        }
    }
}

extension SeasonView {
    @MainActor
    func toggleMonitor() async {
        guard let index = series.seasons.firstIndex(where: { $0.id == season.id }) else {
            return
        }

        series.seasons[index].monitored.toggle()

        guard await instance.series.push(series) else {
            return
        }

        dependencies.toast.show(season.monitored ? .monitored : .unmonitored)
    }

    @MainActor
    func reload() async {
        _ = await instance.series.get(series)
        await instance.episodes.fetch(series)
    }

    @MainActor
    func dispatchSearch() async {
        guard await instance.series.command(
            .seasonSearch(series.id, season: season.id)
        ) else {
            return
        }

        dependencies.toast.show(.seasonSearchQueued)

        TelemetryDeck.signal("automaticSearchDispatched", parameters: ["type": "season"])
        maybeAskForReview()
    }
}

#Preview {
    let series: [Series] = PreviewData.load(name: "series")
    let item = series.first(where: { $0.id == 67 }) ?? series[0] // 15

    dependencies.router.selectedTab = .series

    dependencies.router.seriesPath.append(
        SeriesPath.series(item.id)
    )

    dependencies.router.seriesPath.append(
        SeriesPath.season(item.id, 2)
    )

    return ContentView()
        .withSonarrInstance(series: series)
        .withAppState()
}
