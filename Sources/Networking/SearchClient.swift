// SearchClient.swift
// Function-style client for the autocomplete endpoint. Constructor-injected.
//
// Transport / logging / cancellation translation are owned by
// `HTTPClient.executeJSON(...)` — this file owns only request construction
// and the lossy-array decode shape.

import Foundation

struct SearchClient: Sendable {
    var search: @Sendable (_ query: String) async throws -> [Place]
}

// MARK: - Live

extension SearchClient {
    static func live(
        environment: APIEnvironment = .staging,
        http: HTTPClient = .live(),
        logger: LogClient = .live
    ) -> SearchClient {
        SearchClient { query in
            let url = Endpoints.placesAutocomplete(matching: query, environment: environment)
            var request = URLRequest(url: url, timeoutInterval: Networking.Constants.requestTimeout)
            request.setMethod(.get)
            return try await http.executeJSON(
                request,
                event: (.searchInitiated, .searchCompleted, .searchFailed),
                payload: ["query": query],
                logger: logger,
                // Lossy decode: a single malformed `Place` row in the
                // staging response shouldn't drop the whole list. The
                // user pays for one bad row by losing 1 of 10, not 10.
                decode: { data in
                    try Decoders.api.decodeLossy([Place].self, from: data)
                }
            )
        }
    }
}

// MARK: - Failing

extension SearchClient {
    static let failing = SearchClient { _ in
        throw NetworkingError.invalidResponse
    }

    /// Fails the first call, then succeeds on every subsequent call.
    /// Used by Maestro to exercise retry-recovery without restarting the app.
    static var failingThenRecovers: SearchClient {
        let counter = CallCounter()
        return SearchClient { query in
            if await counter.incrementAndGet() == 1 {
                throw NetworkingError.invalidResponse
            }
            return Place.fixturesMatching(query)
        }
    }
}

// MARK: - Preview

extension SearchClient {
    static let preview = SearchClient { query in
        // Three sample places for design previews and snapshot tests.
        Place.fixturesMatching(query)
    }
}
