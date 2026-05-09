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
                let places = try decoder.decode([Place].self, from: data)
                logger.info("search.completed", ["count": "\(places.count)"])
                return places
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

// MARK: - Preview fixtures

extension Place {
    static func fixturesMatching(_ query: String) -> [Place] {
        let all = [
            Place(placeID: 236, objectID: "Newport Beach, California", name: "Newport Beach, California", type: "city", cityName: "Newport Beach", stateCode: "CA", countryCode: "US", latitude: 33.6189, longitude: -117.9298),
            Place(placeID: 1265, objectID: "Newport, Rhode Island", name: "Newport, Rhode Island", type: "city", cityName: "Newport", stateCode: "RI", countryCode: "US", latitude: 41.4901, longitude: -71.3128),
            Place(placeID: 14, objectID: "Jamaica", name: "Jamaica", type: "country", cityName: "", stateCode: "", countryCode: "JM", latitude: 18.1096, longitude: -77.2975)
        ]
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}
