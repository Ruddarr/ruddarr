import SwiftUI

struct MovieSearchView: View {
    let instance: Instance

    @State private var searchQuery = ""
    @State private var isSearching = true
    @State private var waitingforResults = false
    @State private var isAddingMovie: MovieLookup?

    @ObservedObject var lookup = MovieLookupModel()

    let gridItemLayout = [
        GridItem(.adaptive(minimum: 250), spacing: 15)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridItemLayout, spacing: 15) {
                ForEach(lookup.movies) { movie in
                    Button {
                        isAddingMovie = movie
                    } label: {
                        MovieLookupRow(movie: movie, instance: instance)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .sheet(item: $isAddingMovie) { movie in
                    MovieLookupSheet(movie: movie)
                }
            }
            .padding(.top, 10)
            .padding(.horizontal)
        }
        .navigationTitle("Search")
        .searchable(
            text: $searchQuery,
            isPresented: $isSearching,
            placement: .navigationBarDrawer(displayMode: .always)
        )
        .onChange(of: searchQuery) {
            Task {
                waitingforResults = true
                print(instance.label)
                await lookup.search(instance, query: searchQuery)
                waitingforResults = false
            }
        }
        .overlay {
            if case .noInternet? = lookup.error {
                NoInternet()
            } else if lookup.movies.isEmpty && !searchQuery.isEmpty && !waitingforResults {
                ContentUnavailableView.search(text: searchQuery)
            }
        }
    }
}

struct MovieLookupRow: View {
    var movie: MovieLookup
    var instance: Instance

    var body: some View {
        HStack {
            CachedAsyncImage(url: movie.remotePoster)
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 120)
                .clipped()

            VStack(alignment: .leading) {
                Text(movie.title)
                    .font(.subheadline)
                    .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                    .multilineTextAlignment(.leading)
                Text(String(movie.year))
                    .font(.caption)
                Spacer()
            }
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(4)
    }
}

struct MovieLookupSheet: View {
    var movie: MovieLookup

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Text("Add movie")
            }
            .navigationTitle(movie.title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: {
                        dismiss()
                    })
                }
            }
        }
    }
}

#Preview {
    // This preview only works when at least one instance was added in settings

    MoviesView(path: .init([MoviesView.Path.search]))
}
