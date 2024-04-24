import Foundation

extension API {
    static var mock: Self {
        .init(fetchMovies: { _ in
            try await Task.sleep(nanoseconds: 1_000_000_000)

            return loadPreviewData(filename: "movies")
        }, lookupMovies: { _, query in
            let movies: [Movie] = loadPreviewData(filename: "movie-lookup")
            try await Task.sleep(nanoseconds: 1_000_000_000)

            return movies.filter {
                $0.title.localizedCaseInsensitiveContains(query)
            }
        }, lookupReleases: { _, _ in
            try await Task.sleep(nanoseconds: 500_000_000)

            return loadPreviewData(filename: "movie-releases")
        }, downloadRelease: { _, _, _ in
            try await Task.sleep(nanoseconds: 1_000_000_000)

            return Empty()
        }, getMovie: { movieId, _ in
            let movies: [Movie] = loadPreviewData(filename: "movies")
            try await Task.sleep(nanoseconds: 2_000_000_000)

            return movies.first(where: { $0.guid == movieId })!
        }, getMovieHistory: { _, _ in
            let events: [MovieHistoryEvent] = loadPreviewData(filename: "movie-history")
            // try await Task.sleep(nanoseconds: 2_000_000_000)

            return events
        }, getMovieFiles: { _, _ in
            let files: [MovieFile] = loadPreviewData(filename: "movie-files")
            // try await Task.sleep(nanoseconds: 500_000_000)

            return files
        }, getMovieExtraFiles: { _, _ in
            let files: [MovieExtraFile] = loadPreviewData(filename: "movie-extra-files")
            // try await Task.sleep(nanoseconds: 500_000_000)

            return files
        }, addMovie: { _, _ in
            let movies: [Movie] = loadPreviewData(filename: "movies")
            try await Task.sleep(nanoseconds: 2_000_000_000)

            return movies[0]
        }, updateMovie: { _, _, _ in
            try await Task.sleep(nanoseconds: 2_000_000_000)

            return Empty()
        }, deleteMovie: { _, _ in
            try await Task.sleep(nanoseconds: 2_000_000_000)

            return Empty()
        }, fetchSeries: { _ in
            try await Task.sleep(nanoseconds: 1_000_000_000)

            return loadPreviewData(filename: "series")
        }, lookupSeries: { _, _ in
            try await Task.sleep(nanoseconds: 1_000_000_000)

            return loadPreviewData(filename: "series-lookup")
        }, movieCalendar: { _, _, _ in
            let movies: [Movie] = loadPreviewData(filename: "calendar-movies")

            return movies
        }, episodeCalendar: { _, _, _ in
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let episodes: [Episode] = loadPreviewData(filename: "calendar-episodes")

            return episodes
        }, command: { _, _ in
            try await Task.sleep(nanoseconds: 2_000_000_000)

            return Empty()
        }, systemStatus: { _ in
            try await Task.sleep(nanoseconds: 2_000_000_000)

            return loadPreviewData(filename: "system-status")
        }, rootFolders: { _ in
            try await Task.sleep(nanoseconds: 1_000_000_000)

            return loadPreviewData(filename: "root-folders")
        }, qualityProfiles: { _ in
            try await Task.sleep(nanoseconds: 1_000_000_000)

            return loadPreviewData(filename: "quality-profiles")
        }, fetchNotifications: { _ in
            try await Task.sleep(nanoseconds: 2_000_000_000)

            return loadPreviewData(filename: "notifications")
        }, createNotification: { _, _ in
            let notifications: [InstanceNotification] = loadPreviewData(filename: "notifications")
            try await Task.sleep(nanoseconds: 2_000_000_000)

            return notifications[0]
        }, updateNotification: { _, _ in
            let notifications: [InstanceNotification] = loadPreviewData(filename: "notifications")
            try await Task.sleep(nanoseconds: 2_000_000_000)

            return notifications[0]
        }, deleteNotification: { _, _ in
            try await Task.sleep(nanoseconds: 2_000_000_000)

            return Empty()
        })
    }
}

fileprivate extension API {
    static func loadPreviewData<Model: Decodable>(filename: String) -> Model {
        if let path = Bundle.main.path(forResource: filename, ofType: "json") {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let data = try Data(contentsOf: URL(fileURLWithPath: path))

                return try decoder.decode(Model.self, from: data)
            } catch {
                fatalError("Preview data `\(filename)` could not be decoded: \(error)")
            }
        }

        fatalError("Preview data `\(filename)` not found")
    }
}
