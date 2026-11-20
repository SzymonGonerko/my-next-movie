import SwiftUI

private let maxCastMembers = 15
private let castPhotoSize: CGFloat = 80
private let castCardWidth: CGFloat = 90
private let castTextMaxLines = 2
private let providerLogoSize: CGFloat = 50
private let providerLogoCornerRadius: CGFloat = 10
private let providerItemWidth: CGFloat = 70
private let providerNameMaxLines = 2
private let recommendationCardWidth: CGFloat = 140

private let symbolNamePerson = "person.fill"
private let symbolNameTrailer = "play.fill"

/// Required by the TMDB terms of use under watch provider data.
private let justWatchAttribution = "Streaming data from JustWatch"

/// Sections under the movie overview. Each one shows only when it has data.
struct MovieDetailSections: View {
    let details: MovieDetails

    var body: some View {
        VStack(alignment: .leading, spacing: spacingExtraLarge) {
            trailerButton
            castSection
            whereToWatchSection
            moreLikeThisSection
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var trailerButton: some View {
        if let address = trailerURL(details) {
            Link(destination: address) { trailerLabel }
                .buttonStyle(.borderedProminent)
        }
    }

    private var trailerLabel: some View {
        Label("Watch Trailer", systemImage: symbolNameTrailer)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, spacingExtraSmall)
    }

    @ViewBuilder
    private var castSection: some View {
        if !details.credits.cast.isEmpty {
            DetailSection(title: "Cast") {
                CastRow(cast: Array(details.credits.cast.prefix(maxCastMembers)))
            }
        }
    }

    @ViewBuilder
    private var whereToWatchSection: some View {
        let countryProviders = watchProviders(details, regionCode: watchRegionCode)
        if hasWatchProviders(countryProviders) {
            DetailSection(title: "Where to Watch") {
                WatchProviderGroups(countryProviders: countryProviders)
            }
        }
    }

    @ViewBuilder
    private var moreLikeThisSection: some View {
        if !details.recommendations.results.isEmpty {
            DetailSection(title: "More Like This") {
                RecommendationRow(movies: details.recommendations.results)
            }
        }
    }
}

/// A section header with the section content under it.
private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacingMedium) {
            Text(title).font(.title3.bold())
            content
        }
    }
}

// MARK: - Cast

private struct CastRow: View {
    let cast: [CastMember]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            cards
        }
        .scrollClipDisabled()
    }

    private var cards: some View {
        HStack(alignment: .top, spacing: spacingMedium) {
            ForEach(cast) { castMember in
                CastMemberCard(castMember: castMember)
            }
        }
    }
}

private struct CastMemberCard: View {
    let castMember: CastMember

    var body: some View {
        VStack(spacing: spacingExtraSmall) {
            CastPhoto(castMember: castMember)
            Text(castMember.name)
                .font(.caption.weight(.semibold))
                .lineLimit(castTextMaxLines)
            Text(castMember.character)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(castTextMaxLines)
        }
        .multilineTextAlignment(.center)
        .frame(width: castCardWidth)
    }
}

/// Round photo of the actor, a person symbol when TMDB has no photo.
private struct CastPhoto: View {
    let castMember: CastMember

    var body: some View {
        photo
            .frame(width: castPhotoSize, height: castPhotoSize)
            .background(.quaternary)
            .clipShape(Circle())
    }

    @ViewBuilder
    private var photo: some View {
        if let address = profileURL(castMember) {
            AsyncImage(url: address) { loadedImage in
                loadedImage.resizable().scaledToFill()
            } placeholder: {
                personSymbol
            }
        } else {
            personSymbol
        }
    }

    private var personSymbol: some View {
        Image(systemName: symbolNamePerson)
            .font(.title)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Where to Watch

private struct WatchProviderGroups: View {
    let countryProviders: CountryWatchProviders

    var body: some View {
        VStack(alignment: .leading, spacing: spacingMedium) {
            WatchProviderGroup(title: "Stream", providers: countryProviders.flatrate ?? [])
            WatchProviderGroup(title: "Rent", providers: countryProviders.rent ?? [])
            WatchProviderGroup(title: "Buy", providers: countryProviders.buy ?? [])
            Text(justWatchAttribution)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// One kind of offer, e.g. "Stream", as a row that scrolls sideways.
private struct WatchProviderGroup: View {
    let title: String
    let providers: [WatchProvider]

    @ViewBuilder
    var body: some View {
        if !providers.isEmpty {
            VStack(alignment: .leading, spacing: spacingSmall) {
                Text(title).font(.subheadline.weight(.semibold))
                providerRow
            }
        }
    }

    private var providerRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            providerItems
        }
        .scrollClipDisabled()
    }

    private var providerItems: some View {
        HStack(alignment: .top, spacing: spacingMedium) {
            ForEach(providers) { provider in
                WatchProviderItem(provider: provider)
            }
        }
    }
}

private struct WatchProviderItem: View {
    let provider: WatchProvider

    var body: some View {
        VStack(spacing: spacingExtraSmall) {
            logo
            Text(provider.providerName)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .lineLimit(providerNameMaxLines)
        }
        .frame(width: providerItemWidth)
    }

    private var logo: some View {
        AsyncImage(url: logoURL(provider)) { loadedImage in
            loadedImage.resizable().scaledToFit()
        } placeholder: {
            Rectangle().fill(.quaternary)
        }
        .frame(width: providerLogoSize, height: providerLogoSize)
        .clipShape(RoundedRectangle(cornerRadius: providerLogoCornerRadius, style: .continuous))
    }
}

// MARK: - More Like This

private struct RecommendationRow: View {
    let movies: [Movie]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            cards
        }
        .scrollClipDisabled()
    }

    private var cards: some View {
        HStack(alignment: .top, spacing: spacingLarge) {
            ForEach(movies) { movie in
                RecommendationCard(movie: movie)
            }
        }
    }
}

/// Opens the details of the recommended movie, like `MovieGridItem` in the grid.
private struct RecommendationCard: View {
    let movie: Movie

    var body: some View {
        NavigationLink(value: movie) {
            MovieCardView(movie: movie)
                .frame(width: recommendationCardWidth)
        }
        .buttonStyle(.plain)
    }
}
