// SearchClient.swift
// Function-style client for the autocomplete endpoint. Constructor-injected.

import Foundation

struct SearchClient: Sendable {
    var search: @Sendable (_ query: String) async throws -> [Place]
}

// MARK: - Live

extension SearchClient {
    static func live(
        environment: APIEnvironment = .staging,
        http: HTTPClient = .live(),
        decoder: JSONDecoder = Decoders.api,
        logger: LogClient = .live
    ) -> SearchClient {
        SearchClient { query in
            logger.debug("search.initiated", ["query": query])
            let url = Endpoints.placesAutocomplete(terms: query, environment: environment)
            var request = URLRequest(url: url, timeoutInterval: Networking.Constants.requestTimeout)
            request.httpMethod = "GET"
            do {
                let (data, _) = try await http.send(request)
                try Task.checkCancellation()
                let response = try decoder.decode(PlacesAutocompleteResponse.self, from: data)
                logger.info("search.completed", ["count": "\(response.places.count)"])
                return response.places
            } catch is CancellationError {
                throw CancellationError()
            } catch let urlError as URLError where urlError.code == .cancelled {
                throw CancellationError()
            } catch {
                logger.error("search.failed", ["error": "\(error)"])
                throw error
            }
        }
    }
}

// MARK: - Failing

extension SearchClient {
    static let failing = SearchClient { _ in
        throw NetworkingError.invalidResponse
    }
}

// MARK: - Preview

extension SearchClient {
    static let preview = SearchClient { query in
        // Three sample places for design previews and snapshot tests.
        Place.fixturesMatching(query)
    }
}

// MARK: - Wire response

private struct PlacesAutocompleteResponse: Decodable {
    let places: [Place]

    enum CodingKeys: String, CodingKey {
        case places = "results"
    }
}

extension Place {
    static func fixturesMatching(_ query: String) -> [Place] {
        let all = [
            Place(id: "newport-beach-ca", name: "Newport Beach, California", latitude: 33.6189, longitude: -117.9298, region: "Newport Beach · Orange County, CA"),
            Place(id: "newport-ri", name: "Newport, Rhode Island", latitude: 41.4901, longitude: -71.3128, region: "Newport · Newport County, RI"),
            Place(id: "newport-or", name: "Newport, Oregon", latitude: 44.6368, longitude: -124.0535, region: "Newport · Lincoln County, OR")
        ]
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}
