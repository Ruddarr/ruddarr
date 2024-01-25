import SwiftUI


struct MoviesView: View {
    @State private var searchQuery = ""
    @State private var searchPresented = false

    @State private var error: Error?
    @State private var alertPresented = false
    /*@AppStorage("movieSort")*/ @State private var sort: MovieSort = .init()

    @State var movies = MovieModel()

    /*@AppStorage("movieInstance", store: dependencies.userDefaults)*/ @State private var selectedInstanceId: UUID?
    @State private var instances: [Instance] = [.sample]

    @Environment(\.scenePhase) private var scenePhase

    enum Path: Hashable {
        case search
        case movie(Movie.ID)
    }

    var onSettingsLinkTapped: () -> Void = { }

    var body: some View {
        let gridItemLayout = [
            GridItem(.adaptive(minimum: 250), spacing: 15)
        ]

        NavigationStack(path: dependencies.$router.moviesPath) {
            Group {
                if let radarrInstance {
                    ScrollView {
                        LazyVGrid(columns: gridItemLayout, spacing: 15) {
                            ForEach(displayedMovies) { movie in
                                NavigationLink(value: Path.movie(movie.id)) {
                                    MovieRow(movie: movie)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, searchPresented ? 10 : 0)
                        .padding(.horizontal)
                    }
                    .task {
                        await fetchMoviesWithAlert(radarrInstance, ignoreOffline: true)
                    }
                    .refreshable {
                        await fetchMoviesWithAlert(radarrInstance)
                    }
                    .onChange(of: scenePhase) { newPhase, oldPhase in
                        guard newPhase == .background && oldPhase == .inactive else { return }

                        Task {
                            await movies.fetch(radarrInstance)
                        }
                    }
                } else {
                    noRadarrInstance
                }
            }
            .navigationTitle("Movies")
            .navigationDestination(for: Path.self) {
                switch $0 {
                case .search:
                    if let radarrInstance {
                        MovieSearchView(instance: radarrInstance)
                    }
                case .movie(let movieId):
                    if let movie = movies.byId(movieId) {
                        MovieView(movie: movie)
                    }
                }
            }
            .onAppear {
                // if no instance is selected, try to select one
                // if the selected instance was deleted, try to select one
                if radarrInstance == nil {
                    selectedInstanceId = radarrInstances.first?.id
                }
            }
            .toolbar {
                toolbarActionButtons
                toolbarSearchButton
            }
            .searchable(
                text: $searchQuery,
                isPresented: $searchPresented,
                placement: .navigationBarDrawer(displayMode: .always)
            )
            .alert("Something Went Wrong", isPresented: $alertPresented) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(error?.localizedDescription ?? "An unknown error occurred.")
            }
            .overlay {
                if case .notConnectedToInternet? = (error as? URLError)?.code {
                    NoInternet()
                } else if displayedMovies.isEmpty && !searchQuery.isEmpty {
                    noSearchResults
                }
            }
        }
    }

    var noRadarrInstance: some View {
        ContentUnavailableView(
            "No Radarr Instance",
            systemImage: "icloud.slash",
            description: Text("Connect a Radarr instance under [Settings](#view).")
        )
        .environment(\.openURL, .init { _ in
            onSettingsLinkTapped()
            return .handled
        })
    }

    var noSearchResults: some View {
        ContentUnavailableView(
            "No Results for \"\(searchQuery)\"",
            systemImage: "magnifyingglass",
            description: Text("Check the spelling or try [adding the movie](#view).")
        ).environment(\.openURL, .init { _ in
            searchQuery = ""
            searchPresented = false
            dependencies.router.moviesPath.append(MoviesView.Path.search)
            return .handled
        })
    }

    @ToolbarContentBuilder
    var toolbarSearchButton: some ToolbarContent {
        if radarrInstance != nil {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: Path.search) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    @ToolbarContentBuilder
    var toolbarActionButtons: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            if radarrInstances.count > 1 {
                toolbarInstancesButton
            }

            toolbarSortingButton
        }
    }

    var toolbarSortingButton: some View {
        Menu("Sorting", systemImage: "arrow.up.arrow.down") {
            Picker(selection: $sort.option, label: Text("Sorting options")) {
                ForEach(MovieSort.Option.allCases) { sortOption in
                    Text(sortOption.title).tag(sortOption)
                }
            }

            Section {
                Picker(selection: $sort.isAscending, label: Text("Sorting direction")) {
                    Text("Ascending").tag(true)
                    Text("Descending").tag(false)
                }
            }
        }
    }

    var toolbarInstancesButton: some View {
        Menu("Instances", systemImage: "xserve.raid") {
            Picker(selection: $selectedInstanceId, label: Text("Instance")) {
                ForEach(radarrInstances) { instance in
                    Text(instance.label).tag(Optional.some(instance.id))
                }
            }
            .onChange(of: selectedInstanceId) {
                Task {
                    await fetchMoviesWithAlert(radarrInstance!)
                }
            }
        }
    }

    var radarrInstances: [Instance] {
        instances.filter { instance in
            instance.type == .radarr
        }
    }

    var radarrInstance: Instance? {
        radarrInstances.first(where: { $0.id == selectedInstanceId })
    }

    var displayedMovies: [Movie] {
        let unsortedMovies: [Movie]

        if searchQuery.isEmpty {
            unsortedMovies = movies.movies
        } else {
            unsortedMovies = movies.movies.filter { movie in
                movie.title.localizedCaseInsensitiveContains(searchQuery)
            }
        }

        let sortedMovies = unsortedMovies.sorted(by: sort.option.isOrderedBefore)

        return sort.isAscending ? sortedMovies : sortedMovies.reversed()
    }

    func fetchMoviesWithAlert(_ instance: Instance, ignoreOffline: Bool = false) async {
        alertPresented = false
        error = nil

        await movies.fetch(instance)

        if movies.hasError {
            error = movies.error

            if ignoreOffline && (movies.error as? URLError)?.code == .notConnectedToInternet {
                return
            }

            alertPresented = movies.hasError
        }
    }
}

struct MovieRow: View {
    var movie: Movie

    var body: some View {
        HStack {
            CachedAsyncImage(url: movie.remotePoster)
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 120)
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) {
                    Text(String(movie.year))
                    // runtime
                    //                    Text("•")
                    //                    Text(String(movie.studio ?? ""))
                }.font(.caption)

                HStack(spacing: 8) {
                    Image(systemName: movie.monitored ? "bookmark.fill" : "bookmark")
                    Text(movie.monitored ? "Monitored" : "Unmonitored")
                }.font(.caption)

                Group {
                    if movie.sizeOnDisk != nil && movie.sizeOnDisk! > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "doc")
                            Text(ByteCountFormatter().string(fromByteCount: Int64(movie.sizeOnDisk!)))
                        }.font(.caption)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "doc")
                            Text("Missing")
                        }.font(.caption)
                    }
                }

                Spacer()
            }
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}

#Preview("Offline") {
    dependencies.api.fetchMovies = { _ in
        throw URLError(.notConnectedToInternet)
    }

    return ContentView()
}

#Preview("Samples Sorted by Year") {
    dependencies.api.fetchMovies = { _ in
        [
            .init(id: 1, title: "a", sortTitle: "a", studio: nil, year: 1999, sizeOnDisk: nil, monitored: false, added: .distantPast, images: []),
            .init(id: 2, title: "b", sortTitle: "b", studio: nil, year: 2024, sizeOnDisk: nil, monitored: false, added: .distantPast, images: []),
        ]
    }
//    dependencies.userDefaults = .mock
    dependencies.userDefaults.setValue(MovieSort(option: .byYear).rawValue, forKey: "movieSort")
    return ContentView()
}

#Preview("Failure") {
    dependencies.api.fetchMovies = { _ in
        throw URLError(.badServerResponse)
    }

    return ContentView()
}
