import os
import SwiftUI

@Observable
class SeriesReleases {
    var instance: Instance

    var items: [SeriesRelease] = []

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isSearching: Bool = false

    var indexers: [String] = []
    var qualities: [String] = []
    var protocols: [String] = []
    var languages: [String] = []
    var customFormats: [String] = []

    init(_ instance: Instance) {
        self.instance = instance
    }

    func search(_ series: Series, _ season: Season.ID?, _ episode: Episode.ID?) async {
        items = []
        error = nil
        isSearching = true

        do {
            items = try await dependencies.api.lookupSeriesReleases(series.id, season, episode, instance)
            setIndexers()
            setQualities()
            setProtocols()
            setLanguages()
            setCustomFormats()
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "series.releases", message: "Series releases lookup failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isSearching = false
    }

    func setIndexers() {
        var seen: Set<String> = []

        indexers = items
            .map { $0.indexerLabel }
            .filter { seen.insert($0).inserted }
            .sorted()
    }

    func setQualities() {
        var seen: Set<String> = []

        qualities = items
            .sorted { $0.quality.quality.resolution > $1.quality.quality.resolution }
            .map { $0.quality.quality.normalizedName }
            .filter { seen.insert($0).inserted }
    }

    func setProtocols() {
        var seen: Set<String> = []

        protocols = items
            .map { $0.type.label }
            .filter { seen.insert($0).inserted }
    }

    func setLanguages() {
        var seen: Set<String> = []

        languages = items
            .map { $0.languages.map { $0.label } }
            .flatMap { $0 }
            .filter { seen.insert($0).inserted }
    }

    func setCustomFormats() {
        let customFormatNames = items
            .filter { $0.hasCustomFormats }
            .flatMap { $0.customFormats.unsafelyUnwrapped.map { $0.label } }

        customFormats = Array(Set(customFormatNames))
    }
}

struct SeriesRelease: Identifiable, Codable {
    var id: String { guid }

    let guid: String

    let type: MediaReleaseType
    let title: String
    let size: Int
    let age: Int
    let ageMinutes: Float
    let rejected: Bool

    let customFormats: [MediaCustomFormat]?
    let customFormatScore: Int

    let indexerId: Int
    let indexer: String?
    let indexerFlags: Int
    let seeders: Int?
    let leechers: Int?

    let quality: MediaQuality
    let languages: [MediaLanguage]
    let rejections: [String]

    let qualityWeight: Int
    let releaseWeight: Int

    let infoUrl: String?

    let fullSeason: Bool

    // TODO: fix this... Which other fields are missing?
    // seasonNumber
    // seriesTitle
    // episodeNumbers
    // absoluteEpisodeNumbers
    // mappedSeasonNumber
    // mappedEpisodeNumbers
    // mappedAbsoluteEpisodeNumbers
    // mappedSeriesId
    // mappedEpisodeInfo
    // downloadAllowed
    // episodeRequested
    // shouldOverride
    // episodeIds
    // episodeId
    // seriesId
    // `special`
    // `isPossibleSpecialEpisode`

    enum CodingKeys: String, CodingKey {
        case guid
        // case mappedMovieId
        case type = "protocol"
        case title
        case size
        case age
        case ageMinutes
        case rejected
        case customFormats
        case customFormatScore
        case indexerId
        case indexer
        case indexerFlags
        case seeders
        case leechers
        case quality
        case languages
        case rejections
        case qualityWeight
        case releaseWeight
        case infoUrl
        case fullSeason
    }

    var isTorrent: Bool {
        type == .torrent
    }

    var isUsenet: Bool {
        type == .usenet
    }

    var isFreeleech: Bool {
        indexerFlags == 1
    }

    var isProper: Bool {
        quality.revision.isProper
    }

    var isRepack: Bool {
        quality.revision.isRepack
    }

    var hasCustomFormats: Bool {
        if let formats = customFormats {
            return !formats.isEmpty
        }

        return false
    }

    // TODO: check this logic...
    var hasNonFreeleechFlags: Bool {
        indexerFlags > 1
    }

    var cleanIndexerFlags: [String] {
        switch indexerFlags {
        case 1: ["Freeleech"]
        case 2: ["Halfleech"]
        case 4: ["DoubleUpload"]
        case 8: ["Internal"]
        case 16: ["Scene"]
        case 32: ["Freeleech75"]
        case 64: ["Freeleech25"]
        default: []
        }
    }

    var indexerLabel: String {
        guard let indexer = indexer, indexer.hasSuffix(" (Prowlarr)") else {
            return indexer ?? String(indexerId)
        }

        return String(indexer.dropLast(11))
    }

    var indexerFlagsLabel: String? {
        indexerFlags == 0 ? nil : cleanIndexerFlags[0]
    }

    var languageLabel: String {
        languageSingleLabel(languages)
    }

    var languagesLabel: String? {
        if languages.isEmpty {
            return String(localized: "Unknown")
        }

        return languages.map { $0.label }
            .formatted(.list(type: .and, width: .narrow))
    }

    var typeLabel: String {
        if type == .torrent {
            return "\(type.label) (\(seeders ?? 0)/\(leechers ?? 0))"
        }

        return type.label
    }

    var sizeLabel: String {
        formatBytes(size)
    }

    var qualityLabel: String {
        let name = quality.quality.name
        let resolution = String(quality.quality.resolution)

        if let label = name {
            if label.contains(resolution) {
                return label
            }

            if quality.quality.resolution > 0 {
                return "\(label) (\(resolution)p)"
            }

            return label
        }

        if quality.quality.resolution > 0 {
            return "\(resolution)p"
        }

        return String(localized: "Unknown")
    }

    var ageLabel: String {
        let minutes: Int = Int(ageMinutes)
        let days: Int = minutes / 60 / 24
        let years: Float = Float(days) / 30 / 12

        return switch minutes {
        case -10_000..<1: // less than 1 minute (or bad data from radarr)
            String(localized: "Just now")
        case 1..<119: // less than 120 minutes
            String(format: String(localized: "%d minutes"), minutes)
        case 120..<2_880: // less than 48 hours
            String(format: String(localized: "%d hours"), minutes / 60)
        case 2_880..<129_600: // less than 90 days
            String(format: String(localized: "%d days"), days)
        case 129_600..<525_600: // less than 365 days
            String(format: String(localized: "%d months"), days / 30)
        case 525_600..<2_628_000: // less than 5 years
            String(format: String(localized: "%.1f years"), years)
        default:
            String(format: String(localized: "%d years"), Int(years))
        }
    }

    var scoreLabel: String {
        formatCustomScore(customFormatScore)
    }
}
