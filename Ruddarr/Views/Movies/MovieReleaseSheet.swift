import SwiftUI

struct MovieReleaseSheet: View {
    @State var release: MovieRelease

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                header
                    .padding(.bottom)

                if !release.rejections.isEmpty {
                    rejections
                        .padding(.bottom)
                }

                actions
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom)

                details
                    .padding(.bottom)
            }
            .padding(.horizontal)
            .padding(.top)
        }
    }

    var header: some View {
        VStack(alignment: .leading) {
            if !release.indexerFlags.isEmpty {
                HStack {
                    ForEach(release.cleanIndexerFlags, id: \.self) { flag in
                        Text(flag).textCase(.uppercase)
                    }
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(settings.theme.tint)
            }

            Text(release.title)
                .font(.title2)
                .fontWeight(.bold)
                .kerning(-0.5)

            HStack(spacing: 6) {
                Text(release.qualityLabel)
                Text("•")
                Text(release.sizeLabel)
                Text("•")
                Text(release.ageLabel)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    var rejections: some View {
        GroupBox(label:
            Text("Release Rejected")
                .padding(.bottom, 4)
        ) {
            VStack(alignment: .leading) {
                ForEach(release.rejections, id: \.self) { rejection in
                    Text(rejection)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

        }
    }

    var actions: some View {
        HStack(spacing: 24) {
            if let url = release.infoUrl {
                Link(destination: URL(string: url)!, label: {


                    ButtonLabel(text: "Open Link", icon: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                })
                .buttonStyle(.bordered)
                .tint(.secondary)
            }

            Button {
                // let body = DownloadMovieRelease(guid: String, indexerId: <#T##Int#>)
                // TODO: needs action
            } label: {
                ButtonLabel(text: "Download", icon: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
    }

    var details: some View {
        Section(
            header: Text("Information")
                .font(.title2)
                .fontWeight(.bold)
        ) {
            VStack(spacing: 12) {
                row("Indexer", value: release.indexerLabel)

                if release.isTorrent {
                    Divider()
                    row("Seeders", value: String(release.seeders ?? 0))
                    Divider()
                    row("Leechers", value: String(release.leechers ?? 0))
                }

                if let language = release.languageLabel {
                    Divider()
                    row("Language", value: language)
                }
            }
            .font(.callout)
        }
    }

    func row(_ label: String, value: String) -> some View {
        LabeledContent {
            Text(value).foregroundStyle(.primary)
        } label: {
            Text(label).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let releases: [MovieRelease] = PreviewData.load(name: "releases")
    let release = releases[50]

    return MovieReleaseSheet(release: release)
        .withAppState()
}
