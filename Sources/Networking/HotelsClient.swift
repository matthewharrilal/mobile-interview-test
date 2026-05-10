// HotelsClient.swift
// Function-style client for the algolia_hotels_v7 endpoint.

import Foundation

struct HotelsClient: Sendable {
    var search: @Sendable (_ location: Place) async throws -> HotelsSearchResponse
}

struct HotelsSearchResponse: Sendable {
    let hotels: [Hotel]
    let currency: Currency
    let total: Int
}

// MARK: - Live

extension HotelsClient {
    static func live(
        environment: APIEnvironment = .staging,
        http: HTTPClient = .live(),
        decoder: JSONDecoder = Decoders.api,
        logger: LogClient = .live
    ) -> HotelsClient {
        HotelsClient { location in
            logger.debug("hotels.initiated", ["location": location.name])
            let url = Endpoints.algoliaHotels(environment: environment)
            var request = URLRequest(url: url, timeoutInterval: Networking.Constants.requestTimeout)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "location": [
                    "latitude": location.latitude ?? 0,
                    "longitude": location.longitude ?? 0
                ],
                "limit": Networking.Constants.hotelsPageSize,
                "offset": 0
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            do {
                let (data, _) = try await http.send(request)
                try Task.checkCancellation()
                let wire = try decoder.decode(HotelsWireResponse.self, from: data)
                let response = HotelsSearchResponse(
                    hotels: wire.hotels,
                    currency: Currency(
                        code: wire.currency?.iso_code ?? "USD",
                        symbol: wire.currency?.symbol ?? "$"
                    ),
                    total: wire.total ?? wire.hotels.count
                )
                logger.info("hotels.completed", ["count": "\(response.hotels.count)"])
                return response
            } catch is CancellationError {
                throw CancellationError()
            } catch let urlError as URLError where urlError.code == .cancelled {
                throw CancellationError()
            } catch {
                logger.error("hotels.failed", ["error": "\(error)"])
                throw error
            }
        }
    }
}

// MARK: - Failing

extension HotelsClient {
    static let failing = HotelsClient { _ in
        throw NetworkingError.invalidResponse
    }

    /// Fails the first call, then succeeds on every subsequent call.
    /// Used by Maestro to exercise retry-recovery without restarting the app.
    static var failingThenRecovers: HotelsClient {
        let counter = CallCounter()
        return HotelsClient { _ in
            if counter.incrementAndGet() == 1 {
                throw NetworkingError.invalidResponse
            }
            return HotelsSearchResponse(
                hotels: Hotel.previewFixtures,
                currency: .usd,
                total: Hotel.previewFixtures.count
            )
        }
    }
}

// MARK: - Preview

extension HotelsClient {
    static let preview = HotelsClient { _ in
        HotelsSearchResponse(
            hotels: Hotel.previewFixtures,
            currency: .usd,
            total: Hotel.previewFixtures.count
        )
    }
}

// MARK: - Wire response

private struct HotelsWireResponse: Decodable {
    let hotels: [Hotel]
    let currency: CurrencyWire?
    let total: Int?

    struct CurrencyWire: Decodable {
        let symbol: String?
        let iso_code: String?
    }
}

extension Hotel {
    static let previewFixtures: [Hotel] = [
        Hotel(
            id: 1, name: "TWA Hotel",
            imageURL: URL(string: "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800"),
            rating: 4.1, reviewCount: 164, distanceMiles: 8, distanceText: "8 mi",
            productName: "Pool Pass 9pm-10:45pm", primaryVibe: "Trendy", cheapestPrice: 50
        ),
        Hotel(
            id: 2, name: "Hyatt Regency JFK",
            imageURL: URL(string: "https://images.unsplash.com/photo-1582719508461-905c673771fd?w=800"),
            rating: 4.3, reviewCount: 89, distanceMiles: 3, distanceText: "3 mi",
            productName: "Day Pass 10am-6pm", primaryVibe: "Modern", cheapestPrice: 75
        ),
        Hotel(
            id: 3, name: "The Ritz-Carlton, Half Moon Bay",
            imageURL: URL(string: "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800"),
            rating: 4.8, reviewCount: 421, distanceMiles: 5, distanceText: "5 mi",
            productName: "Pool & Spa Day Pass", primaryVibe: "Luxury", cheapestPrice: 195
        )
    ]
}
