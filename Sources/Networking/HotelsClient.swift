// HotelsClient.swift
// Function-style client for the algolia_hotels_v7 endpoint.

import Foundation

struct HotelsClient: Sendable {
    var search: @Sendable (_ location: Place) async throws -> HotelsSearchResponse
}

struct HotelsSearchResponse: Sendable {
    let hotels: [Hotel]
    let currency: Currency
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
                    hotels: wire.hits,
                    currency: Currency(code: wire.currency ?? "USD", symbol: "$")
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
}

// MARK: - Preview

extension HotelsClient {
    static let preview = HotelsClient { _ in
        HotelsSearchResponse(
            hotels: Hotel.previewFixtures,
            currency: .usd
        )
    }
}

// MARK: - Wire response

private struct HotelsWireResponse: Decodable {
    let hits: [Hotel]
    let currency: String?
}

extension Hotel {
    static let previewFixtures: [Hotel] = [
        Hotel(
            id: "twa-hotel",
            name: "TWA Hotel",
            imageURL: URL(string: "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800"),
            rating: 4.1,
            reviewCount: 164,
            distanceMiles: 8,
            vibes: ["Trendy"],
            priceCents: 5000,
            productName: "Pool Pass 9pm-10:45pm"
        ),
        Hotel(
            id: "hyatt-jfk",
            name: "Hyatt Regency JFK",
            imageURL: URL(string: "https://images.unsplash.com/photo-1582719508461-905c673771fd?w=800"),
            rating: 4.3,
            reviewCount: 89,
            distanceMiles: 3,
            vibes: ["Modern"],
            priceCents: 7500,
            productName: "Day Pass 10am-6pm"
        ),
        Hotel(
            id: "ritz-half-moon-bay",
            name: "The Ritz-Carlton, Half Moon Bay",
            imageURL: URL(string: "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800"),
            rating: 4.8,
            reviewCount: 421,
            distanceMiles: 5,
            vibes: ["Luxury", "Coastal"],
            priceCents: 19500,
            productName: "Pool & Spa Day Pass"
        )
    ]
}
