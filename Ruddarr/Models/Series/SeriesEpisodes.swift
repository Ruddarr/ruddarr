import os
import SwiftUI

@Observable
class SeriesEpisodes {
    var instance: Instance

    var items: [Episode] = []

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isFetching: Bool = false
    var isMonitoring: Bool = false

    init(_ instance: Instance) {
        self.instance = instance
    }

    func fetched(_ series: Series) -> Bool {
        items.contains { $0.seriesId == series.id }
    }

    func maybeFetch(_ series: Series) async {
        if !fetched(series) { await fetch(series) }
    }

    func fetch(_ series: Series) async {
        items = []
        error = nil
        isFetching = true

        do {
            items = try await dependencies.api.fetchEpisodes(series.id, instance)
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "series.episodes", message: "Episodes fetch failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isFetching = false
    }

    func monitor(_ episodes: [Episode.ID], _ monitored: Bool) async -> Bool {
        error = nil
        isMonitoring = true

        do {
            _ = try await dependencies.api.monitorEpisode(episodes, monitored, instance)
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            error = apiError

            leaveBreadcrumb(.error, category: "series.episodes", message: "Episode monitor failed", data: ["error": apiError])
        } catch {
            self.error = API.Error(from: error)
        }

        isMonitoring = false

        return error == nil
    }
}
