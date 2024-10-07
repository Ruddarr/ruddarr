import os
import SwiftUI

@Observable
class SeriesModel {
    var instance: Instance

    var items: [Series] = []
    var itemsCount: Int = 0

    var cachedItems: [Series] = []
    var alternateTitles: [Series.ID: String] = [:]

    var error: API.Error?
    var errorBinding: Binding<Bool> { .init(get: { self.error != nil }, set: { _ in }) }

    var isWorking: Bool = false

    enum Operation {
        case fetch
        case get(Series)
        case add(Series)
        case push(Series)
        case update(Series, Bool)
        case delete(Series, Bool)
        case download(String, Int, Int?, Int?, Int?)
        case command(InstanceCommand)
    }

    init(_ instance: Instance) {
        self.instance = instance
    }

    func sortAndFilterItems(_ sort: SeriesSort, _ searchQuery: String) {
        cachedItems = sort.filter.filtered(items)

        let query = searchQuery.trimmingCharacters(in: .whitespaces)

        if !query.isEmpty {
            cachedItems = cachedItems.filter { series in
                series.title.localizedCaseInsensitiveContains(query) ||
                series.network?.localizedCaseInsensitiveContains(query) ?? false ||
                alternateTitles[series.id]?.localizedCaseInsensitiveContains(query) ?? false
            }
        }

        cachedItems = cachedItems.sorted(by: sort.option.isOrderedBefore)

        if !sort.isAscending {
            cachedItems = cachedItems.reversed()
        }
    }

    func byId(_ id: Series.ID) -> Binding<Series?> {
        Binding(
            get: { [weak self] in
                guard let index = self?.items.firstIndex(where: { $0.guid == id }) else {
                    return nil
                }

                return self?.items[index]
            },
            set: { [weak self] in
                guard let index = self?.items.firstIndex(where: { $0.guid == id }) else {
                    if let newValue = $0 {
                        self?.items.append(newValue)
                    }

                    return
                }

                if let newValue = $0 {
                    self?.items[index] = newValue
                } else {
                    self?.items.remove(at: index)
                }
            }
        )
    }

    func byTvdbId(_ tvdbId: Int) -> Series? {
        items.first(where: { $0.tvdbId == tvdbId })
    }

    func fetch() async -> Bool {
        await request(.fetch)
    }

    func get(_ series: Series, silent: Bool = false) async -> Bool {
        await request(.get(series), silent: silent)
    }

    func add(_ series: Series) async -> Bool {
        await request(.add(series))
    }

    func push(_ series: Series) async -> Bool {
        await request(.push(series))
    }

    func update(_ series: Series, moveFiles: Bool = false) async -> Bool {
        await request(.update(series, moveFiles))
    }

    func delete(_ series: Series, addExclusion: Bool = false) async -> Bool {
        await request(.delete(series, addExclusion))
    }

    func download(guid: String, indexerId: Int, seriesId: Int?, seasonId: Int?, episodeId: Int?) async -> Bool {
        await request(.download(guid, indexerId, seriesId, seasonId, episodeId))
    }

    func command(_ command: InstanceCommand) async -> Bool {
        await request(.command(command))
    }

    @MainActor
    func request(_ operation: Operation, silent: Bool = false) async -> Bool {
        if !silent {
            error = nil
            isWorking = true
        }

        do {
            try await performOperation(operation)
        } catch is CancellationError {
            // do nothing
        } catch let apiError as API.Error {
            if !silent {
                error = apiError
            }

            leaveBreadcrumb(.error, category: "series", message: "Request failed", data: ["operation": operation, "error": apiError])
        } catch {
            if !silent {
                self.error = API.Error(from: error)
            }
        }

        if !silent {
            isWorking = false
        }

        return error == nil
    }

    @MainActor
    private func performOperation(_ operation: Operation) async throws {
        switch operation {
        case .fetch:
            items = try await dependencies.api.fetchSeries(instance)
            itemsCount = items.count
            computeAlternateTitles()
            await Spotlight(instance.id).index(items, delay: .seconds(5))

            leaveBreadcrumb(.info, category: "series", message: "Fetched series", data: ["count": items.count])

        case .get(let series):
            if let index = items.firstIndex(where: { $0.id == series.id }) {
                let item = try await dependencies.api.getSeries(series.id, instance)

                if items[index] != item {
                    items[index] = item
                }
            }

        case .add(let series):
            items.append(try await dependencies.api.addSeries(series, instance))

        case .push(let series):
            _ = try await dependencies.api.pushSeries(series, instance)

        case .update(let series, let moveFiles):
            _ = try await dependencies.api.updateSeries(series, moveFiles, instance)

        case .delete(let series, let addExclusion):
            _ = try await dependencies.api.deleteSeries(series, addExclusion, instance)
            items.removeAll(where: { $0.guid == series.guid })

        case .download(let guid, let indexerId, let seriesId, let seasonId, let episodeId):
            let payload = episodeId == nil
                ? DownloadReleaseCommand(guid: guid, indexerId: indexerId, seriesId: seriesId, seasonId: seasonId)
                : DownloadReleaseCommand(guid: guid, indexerId: indexerId, episodeId: episodeId)
            _ = try await dependencies.api.downloadRelease(payload, instance)

        case .command(let command):
            _ = try await dependencies.api.command(command, instance)
        }
    }

    private func computeAlternateTitles() {
        if alternateTitles.count == items.count {
            return
        }

        Task.detached(priority: .medium) {
            var titles: [Series.ID: String] = [:]

            for index in self.items.indices {
                titles[self.items[index].id] = self.items[index].alternateTitlesString() ?? ""
            }

            self.alternateTitles = titles
        }
    }
}
