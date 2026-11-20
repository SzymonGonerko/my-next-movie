import Foundation
import Testing

@testable import MyNextMovie

/// The Matrix with an actor without a photo, a director listed twice,
/// an unofficial trailer before the official one, an empty certification before "16" in Poland,
/// and in Poland one service in a subscription and one to rent.
private let matrixDetailsJSON = """
    {
      "id": 603,
      "tagline": "Believe the unbelievable.",
      "runtime": 136,
      "credits": {
        "cast": [
          {"id": 6384, "name": "Keanu Reeves", "character": "Neo", "profile_path": "/8RZL.jpg"},
          {"id": 2975, "name": "Laurence Fishburne", "character": "Morpheus", "profile_path": null}
        ],
        "crew": [
          {"id": 9340, "name": "Lana Wachowski", "job": "Director"},
          {"id": 9339, "name": "Lilly Wachowski", "job": "Director"},
          {"id": 9340, "name": "Lana Wachowski", "job": "Director"},
          {"id": 9340, "name": "Lana Wachowski", "job": "Writer"}
        ]
      },
      "videos": {
        "results": [
          {"key": "unofficial-key", "site": "YouTube", "type": "Trailer", "official": false},
          {"key": "vKQi3bBA1y8", "site": "YouTube", "type": "Trailer", "official": true}
        ]
      },
      "release_dates": {
        "results": [
          {"iso_3166_1": "PL", "release_dates": [{"certification": ""}, {"certification": "16"}]},
          {"iso_3166_1": "US", "release_dates": [{"certification": "R"}]}
        ]
      },
      "watch/providers": {
        "results": {
          "PL": {
            "link": "https://www.themoviedb.org/movie/603-the-matrix/watch?locale=PL",
            "flatrate": [
              {"provider_id": 119, "provider_name": "Amazon Prime Video", "logo_path": "/gMZd.png"}
            ],
            "rent": [
              {"provider_id": 2, "provider_name": "Apple TV", "logo_path": "/peUR.png"}
            ]
          }
        }
      },
      "recommendations": {
        "results": [
          {
            "id": 604,
            "title": "The Matrix Reloaded",
            "overview": "Neo and the rebels fight the machines.",
            "release_date": "2003-05-15",
            "poster_path": "/9TGHDvWrqKBzwDxDodHYXEmOE6J.jpg",
            "vote_average": 7.1,
            "genre_ids": [28, 878]
          }
        ]
      }
    }
    """

/// An announced movie: TMDB does not know its runtime and has no lists for it yet.
private let announcedMovieDetailsJSON = """
    {
      "id": 1,
      "tagline": "",
      "runtime": null,
      "credits": {"cast": [], "crew": []},
      "videos": {"results": []},
      "release_dates": {"results": []},
      "watch/providers": {"results": {}},
      "recommendations": {"results": []}
    }
    """

@MainActor
struct MovieDetailsDecodingTests {
    @Test func decodesTaglineAndRuntime() throws {
        let details = try decodeMatrixDetails()
        #expect(details.id == 603)
        #expect(details.tagline == "Believe the unbelievable.")
        #expect(details.runtime == 136)
    }

    @Test func decodesCastWithAndWithoutPhoto() throws {
        let cast = try decodeMatrixDetails().credits.cast
        #expect(cast.count == 2)
        #expect(cast[0].profilePath == "/8RZL.jpg")
        #expect(cast[1].profilePath == nil)
    }

    @Test func decodesWatchProvidersUnderSlashKey() throws {
        let details = try decodeMatrixDetails()
        let polishProviders = try #require(details.watchProviders.results["PL"])
        #expect(polishProviders.flatrate?.first?.providerName == "Amazon Prime Video")
        #expect(polishProviders.rent?.first?.providerId == 2)
        #expect(polishProviders.buy == nil)
    }

    @Test func decodesCountryCodeOfReleaseDates() throws {
        let details = try decodeMatrixDetails()
        #expect(details.releaseDates.results.first?.countryCode == "PL")
    }

    @Test func decodesRecommendationsAsMovies() throws {
        let recommendations = try decodeMatrixDetails().recommendations.results
        let firstRecommendation = try #require(recommendations.first)
        #expect(firstRecommendation.title == "The Matrix Reloaded")
        #expect(releaseYear(firstRecommendation) == "2003")
    }

    @Test func decodesAnnouncedMovieWithoutRuntime() throws {
        let details = try decodeTMDBMovieDetails(Data(announcedMovieDetailsJSON.utf8))
        #expect(details.runtime == nil)
        #expect(formattedRuntime(details) == "")
        #expect(!hasWatchProviders(watchProviders(details, regionCode: "PL")))
    }
}

@MainActor
struct MovieDetailsTests {
    @Test func runtimeInHoursAndMinutes() {
        #expect(formattedRuntime(makeMovieDetails(runtime: 136)) == "2h 16m")
        #expect(formattedRuntime(makeMovieDetails(runtime: 120)) == "2h 0m")
    }

    @Test func runtimeUnderAnHourHasOnlyMinutes() {
        #expect(formattedRuntime(makeMovieDetails(runtime: 45)) == "45m")
    }

    @Test func runtimeIsEmptyWhenUnknown() {
        #expect(formattedRuntime(makeMovieDetails(runtime: nil)) == "")
        #expect(formattedRuntime(makeMovieDetails(runtime: 0)) == "")
    }

    @Test func directorsAreListedOnceEach() throws {
        let details = try decodeMatrixDetails()
        #expect(directorNames(details) == "Lana Wachowski, Lilly Wachowski")
    }

    @Test func directorsAreEmptyWithoutDirector() {
        let writer = CrewMember(id: 1, name: "Some Writer", job: "Writer")
        #expect(directorNames(makeMovieDetails(crew: [writer])) == "")
    }

    @Test func certificationSkipsEmptyOnes() throws {
        let details = try decodeMatrixDetails()
        #expect(ageCertification(details, regionCode: "PL") == "16")
        #expect(ageCertification(details, regionCode: "US") == "R")
    }

    @Test func certificationIsEmptyForOtherCountry() throws {
        let details = try decodeMatrixDetails()
        #expect(ageCertification(details, regionCode: "DE") == "")
    }

    @Test func officialTrailerWins() throws {
        let details = try decodeMatrixDetails()
        #expect(trailerKey(details) == "vKQi3bBA1y8")
    }

    @Test func unofficialTrailerWhenNoOfficial() {
        let videos = [
            Video(key: "official-teaser", site: "YouTube", type: "Teaser", official: true),
            Video(key: "unofficial-trailer", site: "YouTube", type: "Trailer", official: false),
        ]
        #expect(trailerKey(makeMovieDetails(videos: videos)) == "unofficial-trailer")
    }

    @Test func trailerOnOtherSiteIsSkipped() {
        let videos = [Video(key: "vimeo-trailer", site: "Vimeo", type: "Trailer", official: true)]
        let details = makeMovieDetails(videos: videos)
        #expect(trailerKey(details) == "")
        #expect(!hasTrailer(details))
    }

    @Test func trailerURLPointsToYouTube() throws {
        let details = try decodeMatrixDetails()
        let trailerAddress = trailerURL(details)
        #expect(trailerAddress == URL(string: "https://www.youtube.com/watch?v=vKQi3bBA1y8"))
    }

    @Test func factsLineAddsRuntimeAndCertification() throws {
        let matrix = makeMovie(releaseDate: "1999-03-31", voteAverage: 8.2)
        let details = try decodeMatrixDetails()
        let factsLine = movieFactsLine(matrix, details, regionCode: "PL")
        #expect(factsLine == "1999 · ★ 8.2 · 2h 16m · 16")
    }

    @Test func factsLineBeforeDetailsLoad() {
        let matrix = makeMovie(releaseDate: "1999-03-31", voteAverage: 8.2)
        #expect(movieFactsLine(matrix, emptyMovieDetails, regionCode: "PL") == "1999 · ★ 8.2")
    }

    @Test func profileURLIsNilWithoutPhoto() throws {
        let cast = try decodeMatrixDetails().credits.cast
        #expect(profileURL(cast[0]) == URL(string: "https://image.tmdb.org/t/p/w185/8RZL.jpg"))
        #expect(profileURL(cast[1]) == nil)
    }
}

@MainActor
private func decodeMatrixDetails() throws -> MovieDetails {
    return try decodeTMDBMovieDetails(Data(matrixDetailsJSON.utf8))
}

@MainActor
private func makeMovieDetails(
    runtime: Int? = nil,
    videos: [Video] = [],
    crew: [CrewMember] = []
) -> MovieDetails {
    return MovieDetails(
        id: 1,
        tagline: "",
        runtime: runtime,
        credits: Credits(cast: [], crew: crew),
        videos: VideoList(results: videos),
        releaseDates: ReleaseDateList(results: []),
        watchProviders: WatchProviderList(results: [:]),
        recommendations: TMDBMoviePage(results: [])
    )
}
