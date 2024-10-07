import SwiftUI
import TelemetryDeck

struct SeriesDetails: View {
    @Binding var series: Series

    @State private var descriptionTruncated = true
    @State private var monitoringSeason: Season.ID?

    @EnvironmentObject var settings: AppSettings
    @Environment(SonarrInstance.self) private var instance

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.deviceType) var deviceType

    var body: some View {
        VStack(alignment: .leading) {
            header
                .padding(.bottom)

            details
                .padding(.bottom)

            if hasDescription {
                description
                    .padding(.bottom)
            }

            if deviceType == .phone && !series.exists {
                actions
                    .padding(.bottom)
            }

            if series.exists {
                if !series.seasons.isEmpty {
                    seasons
                }

                information
                    .padding(.bottom)
            }
        }
    }

    var hasDescription: Bool {
        !(series.overview ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    var description: some View {
        HStack(alignment: .top) {
            Text(series.overview ?? "")
                .font(.callout)
                .transition(.slide)
                .lineLimit(descriptionTruncated ? 4 : nil)
                .textSelection(.enabled)
                .onTapGesture {
                    withAnimation(.spring(duration: 0.35)) { descriptionTruncated = false }
                }

            Spacer()
        }
        .onAppear {
            descriptionTruncated = deviceType == .phone
        }
    }

    var details: some View {
        Grid(alignment: .leading) {
            MediaDetailsRow("Status", value: "\(series.status.label)")

            if !series.exists && series.seasonCount != 0 {
                MediaDetailsRow("Seasons", value: series.seasonCount.formatted())
            }

            if let network = series.network, !network.isEmpty {
                MediaDetailsRow("Network", value: network)
            }

            if !series.genres.isEmpty {
                MediaDetailsRow("Genre", value: series.genreLabel)
            }

            if let episode = nextEpisode {
                MediaDetailsRow("Airing", value: episode.airDateTimeShortLabel)
            }
        }
    }

    @ViewBuilder
    var actions: some View {
        HStack(spacing: 24) {
            if series.exists {
                seriesActions
            } else {
                previewActions
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 450)
    }

    var seriesActions: some View {
        Group {
            Button {
                Task { @MainActor in
                    guard await instance.series.command(.seriesSearch(series.id)) else {
                        return
                    }

                    dependencies.toast.show(.monitoredSearchQueued)

                    TelemetryDeck.signal("automaticSearchDispatched", parameters: ["type": "series"])
                }
            } label: {
                ButtonLabel(text: "Search Monitored", icon: "magnifyingglass")
                    .modifier(MediaPreviewActionModifier())
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .allowsHitTesting(!instance.series.isWorking)

            Spacer()
                .modifier(MediaPreviewActionSpacerModifier())
        }
    }

    var previewActions: some View {
        Group {
            Menu {
                SeriesContextMenu(series: series)
            } label: {
                ButtonLabel(text: "Open In...", icon: "arrow.up.right.square")
                    .modifier(MediaPreviewActionModifier())
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            Spacer()
                .modifier(MediaPreviewActionSpacerModifier())
        }
    }

    var qualityProfile: String {
        instance.qualityProfiles.first(
            where: { $0.id == series.qualityProfileId }
        )?.name ?? String(localized: "Unknown")
    }

    var seasons: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(series.seasons.reversed()) { season in
                    NavigationLink(value: SeriesPath.season(series.id, season.id)) {
                        GroupBox {
                            HStack(spacing: 12) {
                                Text(season.label)
                                    .fontWeight(.medium)

                                if let progress = season.progressLabel {
                                    Text(progress)
                                        .font(.footnote)
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button {
                                    Task { await monitorSeason(season.id) }
                                } label: {
                                    if monitoringSeason == season.id {
                                        ProgressView().tint(.secondary).offset(x: 1.5)
                                    } else {
                                        Image(systemName: "bookmark")
                                            .symbolVariant(season.monitored ? .fill : .none)
                                            .foregroundStyle(colorScheme == .dark ? .lightGray : .darkGray)
                                    }
                                }
                                .buttonStyle(.plain)
                                .overlay(Rectangle().padding(18))
                                .allowsHitTesting(!instance.series.isWorking)
                                .disabled(!series.monitored)
                            }
                        }
                    }.buttonStyle(.plain)
                }
            }
        } header: {
            Text("Seasons")
                .font(.title2.bold())
                .padding(.bottom, 6)
        }
    }

    var nextEpisode: Episode? {
        guard let nextAiring = series.nextAiring else { return nil }
        return instance.episodes.items.first { $0.airDateUtc == nextAiring }
    }

    @MainActor
    func monitorSeason(_ season: Season.ID) async {
        guard let index = series.seasons.firstIndex(where: { $0.id == season }) else {
            return
        }

        series.seasons[index].monitored.toggle()

        monitoringSeason = season

        guard await instance.series.push(series) else {
            monitoringSeason = nil
            return
        }

        monitoringSeason = nil

        dependencies.toast.show(series.seasons[index].monitored ? .monitored : .unmonitored)
    }
}

struct SeriesDetailsPreview: View {
    let series: [Series]
    @State var item: Series

    init(_ file: String) {
        let series: [Series] = PreviewData.load(name: file)
        self.series = series
        self._item = State(initialValue: series.first(where: { $0.id == 67 }) ?? series[0])
    }

    var body: some View {
        SeriesDetailView(series: $item)
            .withSonarrInstance(series: series)
            .withAppState()
    }
}

#Preview("Preview") {
    SeriesDetailsPreview("series-lookup")
}

#Preview {
    SeriesDetailsPreview("series")
}
