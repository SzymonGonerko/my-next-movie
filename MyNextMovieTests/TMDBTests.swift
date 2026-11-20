import Foundation
import Testing

@testable import MyNextMovie

private let testAPIKey = "test-key"

private let popularMoviesJSON = """
    {
      "page": 1,
      "results": [
        {
          "id": 603,
          "title": "The Matrix",
          "overview": "A hacker learns that the world is a simulation.",
          "release_date": "1999-03-31",
          "poster_path": "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
          "vote_average": 8.2,
          "genre_ids": [28, 878]
        }
      ]
    }
    """

private let movieWithoutPosterJSON = """
    {
      "results": [
        {
          "id": 1,
          "title": "Announced",
          "overview": "",
          "release_date": "",
          "poster_path": null,
          "vote_average": 0,
          "genre_ids": []
        }
      ]
    }
    """

private let tmdbErrorJSON = """
    {"status_code": 7, "status_message": "Invalid API key."}
    """

@MainActor
struct TMDBTests {
    @Test func decodesSnakeCaseKeys() throws {
        let movies = try decodeTMDBMovies(Data(popularMoviesJSON.utf8))
        let matrix = try #require(movies.first)
        #expect(matrix.releaseDate == "1999-03-31")
        #expect(matrix.posterPath == "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg")
        #expect(matrix.voteAverage == 8.2)
        #expect(matrix.genreIds == [genreIdAction, genreIdScienceFiction])
    }

    @Test func decodesMissingPosterAsNil() throws {
        let movies = try decodeTMDBMovies(Data(movieWithoutPosterJSON.utf8))
        let announcedMovie = try #require(movies.first)
        #expect(announcedMovie.posterPath == nil)
    }

    @Test func decodingFailsForOtherJSON() {
        #expect(throws: DecodingError.self) {
            try decodeTMDBMovies(Data(tmdbErrorJSON.utf8))
        }
    }

    @Test func popularURLHasAPIKey() throws {
        let popularURL = try #require(tmdbPopularURL(apiKey: testAPIKey))
        let expectedAddress = "https://api.themoviedb.org/3/movie/popular?api_key=test-key"
        #expect(popularURL.absoluteString == expectedAddress)
    }

    @Test func searchWithTextUsesSearchEndpoint() throws {
        let searchURL = try #require(
            tmdbSearchURL(query: "matrix", genreId: noGenreId, apiKey: testAPIKey)
        )
        #expect(searchURL.path() == "/3/search/movie")
        #expect(queryValue(searchURL, "query") == "matrix")
    }

    @Test func searchWithGenreOnlyUsesDiscoverEndpoint() throws {
        let searchURL = try #require(
            tmdbSearchURL(query: "  ", genreId: genreIdAnimation, apiKey: testAPIKey)
        )
        #expect(searchURL.path() == "/3/discover/movie")
        #expect(queryValue(searchURL, "with_genres") == String(genreIdAnimation))
        #expect(queryValue(searchURL, "query") == nil)
    }

    @Test func searchTextIsPercentEncoded() throws {
        let searchURL = try #require(
            tmdbSearchURL(query: "pan tadeusz", genreId: noGenreId, apiKey: testAPIKey)
        )
        #expect(searchURL.absoluteString.contains("query=pan%20tadeusz"))
    }

    @Test func detailsURLAppendsEveryPart() throws {
        let detailsURL = try #require(tmdbMovieDetailsURL(movieId: 603, apiKey: testAPIKey))
        let appendedParts = queryValue(detailsURL, "append_to_response") ?? ""
        #expect(detailsURL.path() == "/3/movie/603")
        #expect(
            appendedParts.split(separator: ",")
                == ["credits", "videos", "release_dates", "watch/providers", "recommendations"]
        )
    }

    @Test func okResponsePasses() throws {
        let response = try makeResponse(statusCode: httpStatusOK)
        #expect(throws: Never.self) {
            try checkTMDBResponse(response)
        }
    }

    @Test func unauthorizedResponseMentionsAPIKey() throws {
        let response = try makeResponse(statusCode: httpStatusUnauthorized)
        let thrownError = #expect(throws: TMDBError.self) {
            try checkTMDBResponse(response)
        }
        #expect(thrownError?.message.contains("API key") == true)
    }

    @Test func otherErrorResponseShowsStatus() throws {
        let response = try makeResponse(statusCode: 404)
        let thrownError = #expect(throws: TMDBError.self) {
            try checkTMDBResponse(response)
        }
        #expect(thrownError?.message.contains("404") == true)
    }
}

/// Value of the query parameter in the address, nil when it is not there.
private func queryValue(_ address: URL, _ parameterName: String) -> String? {
    let components = URLComponents(url: address, resolvingAgainstBaseURL: false)
    for queryItem in components?.queryItems ?? [] {
        if queryItem.name == parameterName {
            return queryItem.value
        }
    }
    return nil
}

private func makeResponse(statusCode: Int) throws -> HTTPURLResponse {
    let address = try #require(URL(string: "https://api.themoviedb.org"))
    let response = HTTPURLResponse(
        url: address,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )
    return try #require(response)
}
