import SwiftUI

/// For previews of views that need a movie: loads popular movies from TMDB first,
/// then shows `content` with them. Needs the TMDB key in `Config/Secrets.xcconfig`.
struct PopularMoviesPreview<Content: View>: View {
    private let content: ([Movie]) -> Content

    @State private var state = LoadState.idle
    @State private var movies: [Movie] = []
    @State private var errorMessage = ""

    init(@ViewBuilder content: @escaping ([Movie]) -> Content) {
        self.content = content
    }

    var body: some View {
        loadedContent
            .task { await load() }
    }

    @ViewBuilder
    private var loadedContent: some View {
        switch state {
        case .idle, .loading:
            ProgressView()
        case .loaded:
            moviesContent
        case .failed:
            Text(errorMessage)
        }
    }

    @ViewBuilder
    private var moviesContent: some View {
        if movies.isEmpty {
            Text("No movies")
        } else {
            content(movies)
        }
    }

    private func load() async {
        state = .loading
        do {
            movies = try await fetchPopularMovies()
            state = .loaded
        } catch {
            errorMessage = error.localizedDescription
            state = .failed
        }
    }
}
