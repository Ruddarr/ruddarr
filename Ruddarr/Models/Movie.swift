import SwiftUI

struct Movie: Identifiable, Codable, Hashable {
    var id: Int { movieId ?? tmdbId }

    var movieId: Int?
    let tmdbId: Int
    let imdbId: String?

    let title: String
    let sortTitle: String
    let studio: String?
    let year: Int
    let runtime: Int
    let overview: String?
    let certification: String?
    let youTubeTrailerId: String?

    let alternateTitles: [AlternateMovieTitle]
    var alternateTitlesString: String?

    mutating func setAlternateTitlesString() {
        alternateTitlesString = alternateTitles.map { $0.title }.joined(separator: " ")
    }

    let genres: [String]
    let ratings: MovieRatings?
    let popularity: Float?

    let status: MovieStatus
    var minimumAvailability: MovieStatus

    var monitored: Bool
    var qualityProfileId: Int
    let sizeOnDisk: Int?
    let hasFile: Bool?
    let isAvailable: Bool

    var path: String?
    var folderName: String?
    var rootFolderPath: String?

    let added: Date
    let inCinemas: Date?
    let physicalRelease: Date?
    let digitalRelease: Date?

    let images: [MovieImage]
    let movieFile: MovieFile?

    enum CodingKeys: String, CodingKey {
        case movieId = "id"
        case tmdbId
        case imdbId
        case title
        case sortTitle
        case alternateTitles
        case studio
        case year
        case runtime
        case overview
        case certification
        case youTubeTrailerId
        case genres
        case ratings
        case popularity
        case status
        case minimumAvailability
        case monitored
        case qualityProfileId
        case sizeOnDisk
        case hasFile
        case isAvailable
        case path
        case folderName
        case rootFolderPath
        case added
        case inCinemas
        case physicalRelease
        case digitalRelease
        case images
        case movieFile
    }

    var exists: Bool {
        movieId != nil
    }

    var stateLabel: String {
        if isDownloaded {
            return String(localized: "Downloaded")
        }

        if isWaiting {
            return String(localized: "Waiting")
        }

        if monitored && isAvailable {
            return String(localized: "Missing")
        }

        return String(localized: "Unwanted")
    }

    var runtimeLabel: String? {
        guard runtime > 0 else { return nil }

        let hours = runtime / 60
        let minutes = runtime % 60

        return hours == 0
            ? String(format: String(localized: "%dm", comment: "%d = minutes (13m)"), minutes)
            : String(format: String(localized: "%dh %dm", comment: "$1 = hours, $2 = minutes (1h 13m)"), hours, minutes)
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

    var sizeLabel: String {
        ByteCountFormatter().string(
            fromByteCount: Int64(sizeOnDisk ?? 0)
        )
    }

    var genreLabel: String {
        genres.formatted(.list(type: .and, width: .narrow))
    }

    var remotePoster: String? {
        if let remote = self.images.first(where: { $0.coverType == "poster" }) {
            return remote.remoteURL
        }

        return nil
    }

    var remoteFanart: String? {
        if let remote = self.images.first(where: { $0.coverType == "fanart" }) {
            return remote.remoteURL
        }

        return nil
    }

    var isDownloaded: Bool {
        hasFile ?? false
    }

    var isWaiting: Bool {
        switch status {
        case .tba, .announced:
            true // status == .announced && digitalRelease <= today
        case .inCinemas:
            minimumAvailability == .released
        case .released, .deleted:
            false
        }
    }

    static func == (lhs: Movie, rhs: Movie) -> Bool {
        lhs.tmdbId == rhs.tmdbId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    struct MovieRatings: Codable {
        let imdb: MovieRating?
        let tmdb: MovieRating?
        let metacritic: MovieRating?
        let rottenTomatoes: MovieRating?
    }
}

enum MovieStatus: String, Codable {
    case tba
    case announced
    case inCinemas
    case released
    case deleted

    var label: String {
        switch self {
        case .tba: String(localized: "TBA")
        case .announced: String(localized: "Announced")
        case .inCinemas: String(localized: "In Cinemas")
        case .released: String(localized: "Released")
        case .deleted: String(localized: "Deleted")
        }
    }
}

struct AlternateMovieTitle: Codable {
    let title: String
}

struct MovieImage: Codable {
    let coverType: String
    let remoteURL: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case coverType
        case remoteURL = "remoteUrl"
        case url
    }
}

struct MovieRating: Codable {
    let votes: Int
    let value: Float
}

struct MovieFile: Codable {
    let mediaInfo: MovieMediaInfo
    let quality: MovieQualityInfo
    let languages: [MovieLanguages]
}

struct MovieMediaInfo: Codable {
    let audioCodec: String?
    let audioChannels: Float?
    let videoCodec: String?
    let resolution: String?
    let videoDynamicRange: String?
    let subtitles: String?

    var subtitleCodes: [String]? {
        guard let languages = subtitles, languages.count > 0 else { return nil }

        let codes = Array(Set(
            languages.components(separatedBy: "/")
        ))

        return codes.sorted(by: Languages.codeSort)
    }
}

struct MovieQualityInfo: Codable {
    let quality: MovieQuality
}

struct MovieQuality: Codable {
    let name: String?
    let resolution: Int
}

struct MovieLanguages: Codable {
    let name: String?
}

struct MovieEditorResource: Codable {
    let movieIds: [Int]
    let monitored: Bool?
    let qualityProfileId: Int?
    let minimumAvailability: MovieStatus?
    let rootFolderPath: String?
    let moveFiles: Bool?
}
