import Foundation

struct CatalogMetadata {
    let artwork: Data?
    let duration: TimeInterval?
    let show: String?
}

enum ArtworkLookup {
    static func fetch(title: String, episodeID: String?) async -> CatalogMetadata? {
        if let episodeID, let exact = await request(path: "lookup", items: [
            URLQueryItem(name: "id", value: episodeID),
            URLQueryItem(name: "entity", value: "podcastEpisode")
        ]).first(where: { normalized($0.trackName ?? "") == normalized(title) }) {
            return await metadata(for: exact)
        }

        let results = await request(path: "search", items: [
            URLQueryItem(name: "term", value: title),
            URLQueryItem(name: "media", value: "podcast"),
            URLQueryItem(name: "entity", value: "podcastEpisode"),
            URLQueryItem(name: "limit", value: "10")
        ])
        guard let match = results.first(where: { normalized($0.trackName ?? "") == normalized(title) }) else {
            return nil
        }
        return await metadata(for: match)
    }

    private static func metadata(for result: SearchResult) async -> CatalogMetadata {
        var artwork: Data?
        if let string = result.artworkUrl600 ?? result.artworkUrl100,
           let url = URL(string: string), url.scheme == "https" {
            artwork = try? await URLSession.shared.data(from: url).0
        }
        return CatalogMetadata(
            artwork: artwork,
            duration: result.trackTimeMillis.map { Double($0) / 1_000 },
            show: result.collectionName
        )
    }

    private static func request(path: String, items: [URLQueryItem]) async -> [SearchResult] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "itunes.apple.com"
        components.path = "/\(path)"
        components.queryItems = items + [URLQueryItem(name: "country", value: "cn")]
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let decoded = try? JSONDecoder().decode(SearchResponse.self, from: data) else { return [] }
        return decoded.results
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .filter { !$0.isWhitespace && !$0.isPunctuation }
    }

    private struct SearchResponse: Decodable { let results: [SearchResult] }
    private struct SearchResult: Decodable {
        let trackName: String?
        let collectionName: String?
        let artworkUrl600: String?
        let artworkUrl100: String?
        let trackTimeMillis: Int?
    }
}
