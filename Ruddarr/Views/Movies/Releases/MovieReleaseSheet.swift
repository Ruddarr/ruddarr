import SwiftUI
import TelemetryClient

struct MovieReleaseSheet: View {
    @State var release: MovieRelease

    @EnvironmentObject var settings: AppSettings
    @Environment(RadarrInstance.self) private var instance

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    let smallScreen = UIDevice.current.userInterfaceIdiom == .phone

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
                .font(.title2)
                .fontWeight(.bold)
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
            if !smallScreen {
                Spacer()
            }

            if let url = release.infoUrl {
                Link(destination: URL(string: url)!, label: {
                    let label: LocalizedStringKey = smallScreen ? "Visit" : "Visit Website"

                    ButtonLabel(text: label, icon: "arrow.up.right.square")
                        .modifier(MediaPreviewActionModifier())
                })
                .buttonStyle(.bordered)
                .tint(.secondary)
            }

            Button {
                Task { await downloadRelease() }
            } label: {
                let label: LocalizedStringKey = smallScreen ? "Download" : "Download Release"

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

            if !smallScreen {
                Spacer()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    var details: some View {
        Section(
            header: Text("Information")
                .font(.title2)
                .fontWeight(.bold)
        ) {
            VStack(spacing: 12) {
                if let languages = release.languagesLabel {
                    row("Language", value: languages)
                    Divider()
                }

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
        }
    }

    func flags() -> [String] {
        var flags: [String] = []

        if release.customFormatScore != 0 {
            flags.append(release.scoreLabel)
        }

        if !release.indexerFlags.isEmpty {
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
    func downloadRelease() async {
        guard await instance.movies.download(
            guid: release.guid,
            indexerId: release.indexerId
        ) else {
            return
        }

        dismiss()
        dependencies.router.moviesPath.removeLast()
        dependencies.toast.show(.downloadQueued)

        TelemetryManager.send("releaseDownloaded", with: ["type": "movie"])
    }
}

#Preview {
    let releases: [MovieRelease] = PreviewData.load(name: "movie-releases")
    let release = releases[5]

    return MovieReleaseSheet(release: release)
        .withAppState()
}
