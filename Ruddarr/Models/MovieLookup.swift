import SwiftUI

class MovieLookupModel: ObservableObject {
    @Published var movies: [MovieLookup] = []
    @Published var error: ApiError?

    func search(_ instance: Instance, query: String) async {
        guard !query.isEmpty else {
            movies = []
            return
        }
        
        let url = URL(string: "\(instance.url)/api/v3/movie/lookup?term=\(query)")!
        
        do {
            movies = try await dependencies.api.lookupMovies(instance, query)
            
        } catch let error as ApiError {
            self.error = error
            print("MovieLookupModel.search(): \(error)")
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }
}

struct MovieLookup: Identifiable, Codable {
    var id: Int {
        tmdbId
    }
    let tmdbId: Int
    let title: String
    let year: Int
    let remotePoster: String?
    let images: [MovieImage]
}
