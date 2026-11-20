import Foundation

// TMDB REST API. See https://developer.themoviedb.org/reference/intro/getting-started
private let tmdbScheme = "https"
private let tmdbHost = "api.themoviedb.org"
private let tmdbPopularPath = "/3/movie/popular"
private let tmdbSearchPath = "/3/search/movie"
private let tmdbDiscoverPath = "/3/discover/movie"
private let tmdbMovieDetailsPathPrefix = "/3/movie/"

private let tmdbParameterAPIKey = "api_key"
private let tmdbParameterQuery = "query"
private let tmdbParameterGenres = "with_genres"
private let tmdbParameterAppendToResponse = "append_to_response"

/// Parts glued to the movie details response, so one request brings everything.
private let tmdbDetailsAppendedParts =
    "credits,videos,release_dates,watch/providers,recommendations"

let httpStatusOK = 200
let httpStatusUnauthorized = 401

private let missingAPIKeyMessage = "Missing TMDB API key. Add it to Config/Secrets.xcconfig."
private let unauthorizedMessage =
    "TMDB rejected the API key. Check the key in Config/Secrets.xcconfig."
private let failedStatusMessage = "TMDB request failed with status "
private let invalidAddressMessage = "Could not build the TMDB address."
private let notHTTPResponseMessage = "TMDB sent a response that is not HTTP."

/// One page of a TMDB movie list.
nonisolated struct TMDBMoviePage: Decodable {
    let results: [Movie]
}

/// An error whose message the screens show as it is.
nonisolated struct TMDBError: LocalizedError {
    let message: String

    var errorDescription: String? {
        return message
    }
}

/// TMDB address with `api_key` as the first parameter, then `parameters`.
func tmdbURL(path: String, parameters: [URLQueryItem], apiKey: String) -> URL? {
    var components = URLComponents()
    components.scheme = tmdbScheme
    components.host = tmdbHost
    components.path = path
    components.queryItems = [URLQueryItem(name: tmdbParameterAPIKey, value: apiKey)] + parameters
    return components.url
}

func tmdbPopularURL(apiKey: String) -> URL? {
    return tmdbURL(path: tmdbPopularPath, parameters: [], apiKey: apiKey)
}

/// With text: `/search/movie` with `query`. Without text: `/discover/movie` with `with_genres`.
func tmdbSearchURL(query: String, genreId: Int, apiKey: String) -> URL? {
    let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
    if !trimmedQuery.isEmpty {
        let queryParameter = URLQueryItem(name: tmdbParameterQuery, value: trimmedQuery)
        return tmdbURL(path: tmdbSearchPath, parameters: [queryParameter], apiKey: apiKey)
    }
    var parameters: [URLQueryItem] = []
    if genreId != noGenreId {
        parameters.append(URLQueryItem(name: tmdbParameterGenres, value: String(genreId)))
    }
    return tmdbURL(path: tmdbDiscoverPath, parameters: parameters, apiKey: apiKey)
}

func tmdbMovieDetailsURL(movieId: Int, apiKey: String) -> URL? {
    let appendParameter = URLQueryItem(
        name: tmdbParameterAppendToResponse,
        value: tmdbDetailsAppendedParts
    )
    let path = tmdbMovieDetailsPathPrefix + String(movieId)
    return tmdbURL(path: path, parameters: [appendParameter], apiKey: apiKey)
}

func decodeTMDBMovies(_ data: Data) throws -> [Movie] {
    return try makeTMDBDecoder().decode(TMDBMoviePage.self, from: data).results
}

func decodeTMDBMovieDetails(_ data: Data) throws -> MovieDetails {
    return try makeTMDBDecoder().decode(MovieDetails.self, from: data)
}

/// Throws `TMDBError` for any status other than 200. `URLSession` does not do it by itself.
func checkTMDBResponse(_ response: URLResponse) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
        throw TMDBError(message: notHTTPResponseMessage)
    }
    if httpResponse.statusCode == httpStatusUnauthorized {
        throw TMDBError(message: unauthorizedMessage)
    }
    if httpResponse.statusCode != httpStatusOK {
        throw TMDBError(message: failedStatusMessage + String(httpResponse.statusCode) + ".")
    }
}

/// A `MovieLoader`: popular movies from TMDB.
func fetchPopularMovies() async throws -> [Movie] {
    let apiKey = try requireTMDBAPIKey()
    let data = try await fetchTMDBData(tmdbPopularURL(apiKey: apiKey))
    return try decodeTMDBMovies(data)
}

/// A `MovieSearch`: movies from TMDB matching the text and the genre.
func searchTMDBMovies(query: String, genreId: Int) async throws -> [Movie] {
    let apiKey = try requireTMDBAPIKey()
    let address = tmdbSearchURL(query: query, genreId: genreId, apiKey: apiKey)
    let data = try await fetchTMDBData(address)
    let foundMovies = try decodeTMDBMovies(data)
    // `/search/movie` does not filter by genre, so the app does it.
    return filterMovies(foundMovies, query: "", genreId: genreId)
}

/// A `MovieDetailsLoader`: details of one movie from TMDB.
func fetchMovieDetails(movieId: Int) async throws -> MovieDetails {
    let apiKey = try requireTMDBAPIKey()
    let data = try await fetchTMDBData(tmdbMovieDetailsURL(movieId: movieId, apiKey: apiKey))
    return try decodeTMDBMovieDetails(data)
}

private func requireTMDBAPIKey() throws -> String {
    let apiKey = tmdbAPIKey()
    if apiKey.isEmpty {
        throw TMDBError(message: missingAPIKeyMessage)
    }
    return apiKey
}

/// Sends the request, checks the status code and returns the response body.
private func fetchTMDBData(_ address: URL?) async throws -> Data {
    guard let address else {
        throw TMDBError(message: invalidAddressMessage)
    }
    let (data, response) = try await URLSession.shared.data(from: address)
    try checkTMDBResponse(response)
    return data
}

private func makeTMDBDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
}
