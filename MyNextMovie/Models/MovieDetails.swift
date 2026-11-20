import Foundation

private let tmdbProfileBaseURL = "https://image.tmdb.org/t/p/w185"
private let tmdbLogoBaseURL = "https://image.tmdb.org/t/p/w92"
private let youTubeWatchBaseURL = "https://www.youtube.com/watch?v="

private let directorJob = "Director"
private let youTubeSite = "YouTube"
private let trailerVideoType = "Trailer"
private let namesSeparator = ", "
private let defaultWatchRegionCode = "PL"
private let minutesPerHour = 60

/// Details of a movie from `/3/movie/{id}` with `append_to_response`.
nonisolated struct MovieDetails: Decodable {
    let id: Int
    let tagline: String
    let runtime: Int?  // nil when TMDB does not know it, e.g. for announced movies
    let credits: Credits
    let videos: VideoList
    let releaseDates: ReleaseDateList
    let watchProviders: WatchProviderList
    let recommendations: TMDBMoviePage

    // "watch/providers" has a slash, so it cannot be a field name.
    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case tagline
        case runtime
        case credits
        case videos
        case releaseDates
        case watchProviders = "watch/providers"
        case recommendations
    }
}

nonisolated struct Credits: Decodable {
    let cast: [CastMember]
    let crew: [CrewMember]
}

nonisolated struct CastMember: Decodable, Identifiable {
    let id: Int
    let name: String
    let character: String
    let profilePath: String?  // nil when TMDB has no photo
}

nonisolated struct CrewMember: Decodable {
    let id: Int
    let name: String
    let job: String
}

nonisolated struct VideoList: Decodable {
    let results: [Video]
}

nonisolated struct Video: Decodable {
    let key: String
    let site: String
    let type: String
    let official: Bool
}

nonisolated struct ReleaseDateList: Decodable {
    let results: [CountryReleaseDates]
}

nonisolated struct CountryReleaseDates: Decodable {
    let countryCode: String
    let releaseDates: [ReleaseDate]

    // "iso_3166_1" becomes "iso31661" after `.convertFromSnakeCase`.
    nonisolated enum CodingKeys: String, CodingKey {
        case countryCode = "iso31661"
        case releaseDates
    }
}

nonisolated struct ReleaseDate: Decodable {
    let certification: String
}

nonisolated struct WatchProviderList: Decodable {
    let results: [String: CountryWatchProviders]  // the key is a country code, e.g. "PL"
}

/// Services with the movie in one country. TMDB leaves out the lists the country does not have.
nonisolated struct CountryWatchProviders: Decodable {
    let link: String
    let flatrate: [WatchProvider]?
    let rent: [WatchProvider]?
    let buy: [WatchProvider]?
}

nonisolated struct WatchProvider: Decodable, Identifiable {
    let providerId: Int
    let providerName: String
    let logoPath: String?

    var id: Int {
        return providerId
    }
}

/// Shown until the real details arrive.
let emptyMovieDetails = MovieDetails(
    id: 0,
    tagline: "",
    runtime: nil,
    credits: Credits(cast: [], crew: []),
    videos: VideoList(results: []),
    releaseDates: ReleaseDateList(results: []),
    watchProviders: WatchProviderList(results: [:]),
    recommendations: TMDBMoviePage(results: [])
)

/// Services of a country TMDB has no data for.
let noWatchProviders = CountryWatchProviders(link: "", flatrate: nil, rent: nil, buy: nil)

/// Country from the phone settings, "PL" when there is none.
let watchRegionCode = Locale.current.region?.identifier ?? defaultWatchRegionCode

/// 136 -> "2h 16m", 45 -> "45m", unknown or 0 -> "".
func formattedRuntime(_ details: MovieDetails) -> String {
    let runtimeInMinutes = details.runtime ?? 0
    if runtimeInMinutes <= 0 {
        return ""
    }
    let hours = runtimeInMinutes / minutesPerHour
    let minutes = runtimeInMinutes % minutesPerHour
    if hours == 0 {
        return "\(minutes)m"
    }
    return "\(hours)h \(minutes)m"
}

/// Names of the directors, each once, "Lana Wachowski, Lilly Wachowski".
func directorNames(_ details: MovieDetails) -> String {
    var names: [String] = []
    for crewMember in details.credits.crew {
        if crewMember.job == directorJob && !names.contains(crewMember.name) {
            names.append(crewMember.name)
        }
    }
    return names.joined(separator: namesSeparator)
}

/// First non-empty age certification in the country, "" when there is none.
func ageCertification(_ details: MovieDetails, regionCode: String) -> String {
    for country in details.releaseDates.results {
        if country.countryCode != regionCode {
            continue
        }
        for releaseDate in country.releaseDates {
            if !releaseDate.certification.isEmpty {
                return releaseDate.certification
            }
        }
    }
    return ""
}

/// YouTube key of the trailer. An official one wins, otherwise the first unofficial one.
func trailerKey(_ details: MovieDetails) -> String {
    var unofficialKey = ""
    for video in details.videos.results {
        if video.site != youTubeSite || video.type != trailerVideoType {
            continue
        }
        if video.official {
            return video.key
        }
        if unofficialKey.isEmpty {
            unofficialKey = video.key
        }
    }
    return unofficialKey
}

func trailerURL(_ details: MovieDetails) -> URL? {
    let key = trailerKey(details)
    if key.isEmpty {
        return nil
    }
    return URL(string: youTubeWatchBaseURL + key)
}

func hasTrailer(_ details: MovieDetails) -> Bool {
    return trailerURL(details) != nil
}

/// "1999 · ★ 8.2 · 2h 16m · 16", without the parts that are missing.
func movieFactsLine(_ movie: Movie, _ details: MovieDetails, regionCode: String) -> String {
    var parts = [yearAndRating(movie)]
    let runtime = formattedRuntime(details)
    if !runtime.isEmpty {
        parts.append(runtime)
    }
    let certification = ageCertification(details, regionCode: regionCode)
    if !certification.isEmpty {
        parts.append(certification)
    }
    return parts.joined(separator: textSeparator)
}

func watchProviders(_ details: MovieDetails, regionCode: String) -> CountryWatchProviders {
    return details.watchProviders.results[regionCode] ?? noWatchProviders
}

func hasWatchProviders(_ countryProviders: CountryWatchProviders) -> Bool {
    let streamProviders = countryProviders.flatrate ?? []
    let rentProviders = countryProviders.rent ?? []
    let buyProviders = countryProviders.buy ?? []
    return !streamProviders.isEmpty || !rentProviders.isEmpty || !buyProviders.isEmpty
}

func profileURL(_ castMember: CastMember) -> URL? {
    return tmdbImageURL(tmdbProfileBaseURL, castMember.profilePath)
}

func logoURL(_ provider: WatchProvider) -> URL? {
    return tmdbImageURL(tmdbLogoBaseURL, provider.logoPath)
}

private func tmdbImageURL(_ baseURL: String, _ imagePath: String?) -> URL? {
    let path = imagePath ?? ""
    if path.isEmpty {
        return nil
    }
    return URL(string: baseURL + path)
}
