import SwiftUI

struct Series: Identifiable, Codable {
    // series only have an `id` after being added
    var id: Int { guid ?? (tvdbId + 100_000) }

    // the remapped `id` field
    var guid: Int?

    let title: String
    let sortTitle: String

    let tvdbId: Int
    let tvRageId: Int?
    let tvMazeId: Int?
    let imdbId: String?

    let status: SeriesStatus
    var seriesType: SeriesType

    let path: String?
    var qualityProfileId: Int?
    var rootFolderPath: String?
    let certification: String?

    let year: Int
    var sortYear: Int { year == 0 ? 2_100 : year }
    let runtime: Int
    let ended: Bool
    var seasonFolder: Bool
    let useSceneNumbering: Bool

    let added: Date
    let firstAired: Date?
    let lastAired: Date?
    let nextAiring: Date?

    var monitored: Bool
    var monitorNewItems: SeriesMonitorNewItems

    let overview: String?
    let network: String?

    let originalLanguage: MediaLanguage

    let alternateTitles: [AlternateMovieTitle]?

    var seasons: [Season]
    let genres: [String]
    let images: [MovieImage]
    let statistics: SeriesStatistics?

    var addOptions: SeriesAddOptions?

    enum CodingKeys: String, CodingKey {
        case guid = "id"
        case title
        case sortTitle
        case tvdbId
        case tvRageId
        case tvMazeId
        case imdbId
        case status
        case seriesType
        case path
        case qualityProfileId
        case rootFolderPath
        case certification
        case year
        case runtime
        case ended
        case seasonFolder
        case useSceneNumbering
        case added
        case firstAired
        case lastAired
        case nextAiring
        case monitored
        case monitorNewItems
        case overview
        case network
        case originalLanguage
        case alternateTitles
        case seasons
        case genres
        case images
        case statistics
    }

    var exists: Bool {
        guid != nil
    }

    var isDownloaded: Bool {
        (statistics?.percentOfEpisodes ?? 0) >= 100
    }

    var isWaiting: Bool {
        if let premiere = firstAired { return premiere > Date.now }
        return status == .upcoming || year == 0 || seasons.isEmpty
    }

    var remotePoster: String? {
        if let remote = self.images.first(where: { $0.coverType == "poster" }) {
            return remote.remoteURL
        }

        return nil
    }

    var genreLabel: String {
        genres.prefix(3)
            .map { $0.replacingOccurrences(of: "Science Fiction", with: "Sci-Fi") }
            .formatted(.list(type: .and, width: .narrow))
    }

    var stateLabel: LocalizedStringKey {
        if isDownloaded {
            return "Downloaded"
        }

        if isWaiting {
            return "Waiting"
        }

        if percentOfEpisodes < 100 {
            return episodeFileCount == 0 ? "Missing" : "Missing Episodes"
        }

        return "Unwanted"
    }

    var yearLabel: String {
        year > 0 ? String(year) : String(localized: "TBA")
    }

    var runtimeLabel: String? {
        guard runtime > 0 else { return nil }
        return formatRuntime(runtime)
    }

    var certificationLabel: String {
        guard let rating = certification else {
            return String(localized: "Unrated")
        }

        if rating.isEmpty || rating == "0" {
            return String(localized: "Unrated")
        }

        return rating
    }

    var seasonCount: Int {
        seasons.filter { $0.seasonNumber != 0 }.count
    }

    var episodeCount: Int {
        statistics?.episodeCount ?? 0
    }

    var episodeFileCount: Int {
        statistics?.episodeFileCount ?? 0
    }

    var percentOfEpisodes: Float {
        statistics?.percentOfEpisodes ?? 0
    }

    func seasonById(_ id: Season.ID) -> Season? {
        seasons.first { $0.id == id }
    }

    func seasonYear(_ id: Season.ID) -> Season? {
        seasons.first { $0.id == id }
    }

    func alternateTitlesString() -> String? {
        alternateTitles?.map { $0.title }.joined(separator: " ")
    }
}

enum SeriesStatus: String, Codable {
    case continuing
    case ended
    case upcoming
    case deleted

    var label: String {
        switch self {
        case .continuing: String(localized: "Continuing")
        case .ended: String(localized: "Ended")
        case .upcoming: String(localized: "Upcoming")
        case .deleted: String(localized: "Deleted")
        }
    }

    var icon: Image {
        switch self {
        case .continuing: Image(systemName: "play.fill")
        case .ended: Image(systemName: "stop.fill")
        case .upcoming: Image(systemName: "clock")
        case .deleted: Image(systemName: "xmark.circle")
        }
    }
}

enum SeriesType: String, Codable, Identifiable, CaseIterable {
    var id: Self { self }

    case standard
    case daily
    case anime

    var label: String {
        switch self {
        case .standard: String(localized: "Standard")
        case .daily: String(localized: "Daily")
        case .anime: String(localized: "Anime")
        }
    }
}

struct SeriesStatistics: Codable {
    let sizeOnDisk: Int
    let episodeCount: Int
    let episodeFileCount: Int
    let percentOfEpisodes: Float
}

enum SeriesMonitorNewItems: String, Codable {
    case all
    case none
}

struct SeriesAddOptions: Codable {
    var monitor: SeriesMonitorType
}

enum SeriesMonitorType: String, Codable, Identifiable, CaseIterable {
    var id: Self { self }

    case unknown
    case all
    case future
    case missing
    case existing
    case firstSeason
    case lastSeason
    case latestSeason // obsolete
    case pilot
    case recent
    case monitorSpecials
    case unmonitorSpecials
    case none
    case skip

    var label: String {
        switch self {
        case .unknown: String(localized: "Unknown")
        case .all: String(localized: "All Episodes")
        case .future: String(localized: "Future Episodes")
        case .missing: String(localized: "Missing Episodes")
        case .existing: String(localized: "Existing Episodes")
        case .recent: String(localized: "Recent Episodes")
        case .pilot: String(localized: "Pilot Episode")
        case .firstSeason: String(localized: "First Season")
        case .lastSeason: String(localized: "Last Season")
        case .latestSeason: ""
        case .monitorSpecials: String(localized: "Monitor Specials")
        case .unmonitorSpecials: String(localized: "Unmonitor Specials")
        case .none: String(localized: "None")
        case .skip: ""
        }
    }
}

struct SeriesEditorResource: Codable {
    let seriesIds: [Int]
    let monitored: Bool?
    let monitorNewItems: SeriesMonitorNewItems
    let seriesType: SeriesType
    let seasonFolder: Bool?
    let qualityProfileId: Int?
    let rootFolderPath: String?
    let moveFiles: Bool?
}
