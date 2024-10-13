import SwiftUI
import TelemetryDeck

struct MovieReleaseSheet: View {
    @State var release: MovieRelease
    @State var movieId: Movie.ID

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var instance

    @Environment(\.dismiss) private var dismiss
    @Environment(\.deviceType) private var deviceType

    @State private var showGrabConfirmation: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CloseButton {
                dismiss()
            }

            ScrollView {
                VStack(alignment: .leading) {
                    header
                        .padding(.bottom)
                        .padding(.trailing, 25)

                    if !release.rejections.isEmpty {
                        rejectionReasons
                            .padding(.bottom)
                    }

                    actions
                        .padding(.bottom)

                    details
                        .padding(.bottom)
                }
                .padding(.top)
                .viewPadding(.horizontal)
            }
            .alert(
                isPresented: instance.movies.errorBinding,
                error: instance.movies.error
            ) { _ in
                Button("OK") { instance.movies.error = nil }
            } message: { error in
                Text(error.recoverySuggestionFallback)
            }
            .alert(
                "Grab Release",
                isPresented: $showGrabConfirmation
            ) {
                Button("Grab Release") { Task { await downloadRelease(force: true) } }
                Button("Cancel", role: .cancel) { }
            } message: {
                let type = String(localized: "movie", comment: "The word 'movie' used mid-sentence")
                Text("The release for this \(type) could not be determined and it may not import automatically. Do you want to grab \"\(release.title)\"?")
            }
        }
    }

    var header: some View {
        VStack(alignment: .leading) {
            if !flags().isEmpty {
                HStack {
                    ForEach(flags(), id: \.self) { flag in
                        Text(flag).textCase(.uppercase)
                    }
                }
                .font(.footnote)
                .fontWeight(.semibold)
                .tracking(1.1)
                .foregroundStyle(settings.theme.tint)
            }

            Text(release.title)
                .font(.title2.bold())
                .kerning(-0.5)

            HStack(spacing: 6) {
                Text(release.qualityLabel)
                Bullet()
                Text(release.sizeLabel)
                Bullet()
                Text(release.ageLabel)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            CustomFormats(tags())
        }
    }

    var rejectionReasons: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle").symbolVariant(.fill)
                Text("Release Rejected")
            }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 7)
                .font(.footnote)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .kerning(0.2)
                .background(.yellow)
                .foregroundStyle(.black)

            VStack(alignment: .leading) {
                ForEach(release.rejections, id: \.self) { rejection in
                    Text(rejection)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .background(.secondarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var actions: some View {
        HStack(spacing: 24) {
            if deviceType != .phone {
                Spacer()
            }

            if let url = release.infoUrl {
                Link(destination: URL(string: url)!, label: {
                    let label: LocalizedStringKey = deviceType == .phone ? "Open" : "Open Website"

                    ButtonLabel(text: label, icon: "arrow.up.right.square")
                        .modifier(MediaPreviewActionModifier())
                })
                .buttonStyle(.bordered)
                .tint(.secondary)
            }

            Button {
                if release.downloadAllowed {
                    Task { await downloadRelease() }
                } else {
                    showGrabConfirmation = true
                }
            } label: {
                let label: LocalizedStringKey = deviceType == .phone ? "Download" : "Download Release"

                ButtonLabel(
                    text: label,
                    icon: "arrow.down.circle",
                    isLoading: instance.movies.isWorking
                )
                .modifier(MediaPreviewActionModifier())
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .allowsHitTesting(!instance.movies.isWorking)

            if deviceType != .phone {
                Spacer()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    var details: some View {
        Section {
            VStack(spacing: 12) {
                row("Language", value: release.languagesLabel)
                Divider()
                row("Indexer", value: release.indexerLabel)

                if release.isTorrent {
                    Divider()
                    row("Peers", value: String(
                        format: "S: %i  L: %i",
                        release.seeders ?? 0,
                        release.leechers ?? 0
                    ))
                }
            }
            .font(.callout)
        } header: {
            Text("Information")
                .font(.title2.bold())
        }
    }

    func flags() -> [String] {
        var flags: [String] = []

        if release.customFormatScore != 0 {
            flags.append(release.scoreLabel)
        }

        if let indexerFlags = release.indexerFlags, !indexerFlags.isEmpty {
            flags.append(contentsOf: release.cleanIndexerFlags)
        }

        return flags
    }

    func tags() -> [String] {
        var tags: [String] = []

        if release.isProper {
            tags.append(String(localized: "Proper"))
        }

        if release.isRepack {
            tags.append(String(localized: "Repack"))
        }

        if release.hasCustomFormats {
            tags.append(contentsOf: release.customFormats!.map { $0.label })
        }

        return tags
    }

    func row(_ label: LocalizedStringKey, value: String) -> some View {
        LabeledContent {
            Text(value).foregroundStyle(.primary)
        } label: {
            Text(label).foregroundStyle(.secondary)
        }
    }

    @MainActor
    func downloadRelease(force: Bool = false) async {
        guard await instance.movies.download(
            guid: release.guid,
            indexerId: release.indexerId,
            movieId: force ? movieId : nil
        ) else {
            return
        }

        dismiss()
        dependencies.router.moviesPath.removeLast()
        dependencies.toast.show(.downloadQueued)

        TelemetryDeck.signal("releaseDownloaded", parameters: ["type": "movie"])
        maybeAskForReview()
    }
}

#Preview {
    let movieId = 145
    let releases: [MovieRelease] = PreviewData.load(name: "movie-releases")
    let release = releases[5]

    return MovieReleaseSheet(release: release, movieId: movieId)
        .withAppState()
}
