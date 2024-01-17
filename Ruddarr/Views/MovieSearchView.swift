import SwiftUI

struct MovieSearchView: View {
    let instance: Instance
    
    @State private var searchQuery = ""
    @State private var isSearching = true
    @State private var waitingforResults = false
    @State private var isAddingMovie: MovieLookup? = nil
    
    @ObservedObject var lookup = MovieLookupModel()
    
    let gridItemLayout = [
        GridItem(.adaptive(minimum: 250), spacing: 15)
    ]
    
    var body: some View {
            ScrollView {
                LazyVGrid(columns: gridItemLayout, spacing: 15) {
                    ForEach(lookup.movies) { movie in
                        Button(action: {
                            isAddingMovie = movie
                        }) {
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
                    await lookup.search(instance, query: searchQuery)
                    waitingforResults = false
                }
            }
            .overlay {
                if lookup.movies.isEmpty && !searchQuery.isEmpty && !waitingforResults {
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
            AsyncImage(
                url: URL(string: movie.remotePoster ?? ""),
                content: { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                },
                placeholder: {
                    ProgressView()
                }
            )
            .frame(width: 85, height: 125)
            
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
    MoviesView(path: .init([MoviesView.Path.search]))
    .withSelectedColorScheme()
}
