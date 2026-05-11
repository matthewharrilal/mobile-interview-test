// HotelsClient.swift
// Function-style client for the algolia_hotels_v7 endpoint.
//
// Transport / logging / cancellation translation are owned by
// `HTTPClient.executeJSON(...)` — this file owns only request construction
// (URL + typed body) and the wire→domain mapping.

import Foundation

struct HotelsClient: Sendable {
    var search: @Sendable (_ location: Place) async throws -> HotelsSearchResponse
}

struct HotelsSearchResponse: Sendable {
    let hotels: [Hotel]
    let currency: Currency
    let total: Int
}

// MARK: - Wire types

/// Typed request body for `/api/search/algolia_hotels_v7`. Replaces the
/// previous `[String: Any]` + JSONSerialization construction so the body
/// schema is checked at compile time and the verbatim spec test can
/// exercise the actual client request.
private struct AlgoliaHotelsRequest: Encodable {
    struct Location: Encodable {
        let latitude: Double
        let longitude: Double
    }
    let location: Location
    let limit: Int
    let offset: Int
}

/// Wire response shape. Decoded once, then mapped to `HotelsSearchResponse`
/// via `toDomain()` to keep transport and domain mapping as separate
/// concerns in the `.live` factory.
private struct HotelsWireResponse: Decodable {
    let hotels: [Hotel]
    let currency: CurrencyWire?
    let total: Int?

    struct CurrencyWire: Decodable {
        let symbol: String?
        let isoCode: String?

        enum CodingKeys: String, CodingKey {
            case symbol
            case isoCode = "iso_code"
        }
    }

    enum CodingKeys: String, CodingKey {
        case hotels, currency, total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.hotels = try container.decodeLossyArray([Hotel].self, forKey: .hotels)
        self.currency = try container.decodeIfPresent(CurrencyWire.self, forKey: .currency)
        self.total = try container.decodeIfPresent(Int.self, forKey: .total)
    }

    func toDomain() -> HotelsSearchResponse {
        HotelsSearchResponse(
            hotels: hotels,
            currency: Currency(
                code: currency?.isoCode ?? Currency.usd.code,
                symbol: currency?.symbol ?? Currency.usd.symbol
            ),
            total: total ?? hotels.count
        )
    }
}

// MARK: - Live

extension HotelsClient {
    static func live(
        environment: APIEnvironment = .staging,
        http: HTTPClient = .live(),
        logger: LogClient = .live
    ) -> HotelsClient {
        HotelsClient { location in
            // Contract: callers must check `place.hasUsableCoordinates`
            // before invoking — the autocomplete VM does this guard before
            // navigation. If the guard is ever weakened this precondition
            // surfaces the contract violation immediately rather than
            // silently querying (0, 0).
            guard let latitude = location.latitude, let longitude = location.longitude else {
                preconditionFailure("HotelsClient.search requires usable coordinates; got nil for \(location.name)")
            }
            let body = AlgoliaHotelsRequest(
                location: .init(latitude: latitude, longitude: longitude),
                limit: Networking.Constants.hotelsPageSize,
                offset: 0
            )
            var request = URLRequest(
                url: Endpoints.algoliaHotels(environment: environment),
                timeoutInterval: Networking.Constants.requestTimeout
            )
            request.setMethod(.post)
            request.setContentType(.json)
            request.httpBody = try Encoders.api.encode(body)

            let wire = try await http.executeJSON(
                request,
                as: HotelsWireResponse.self,
                event: (.hotelsInitiated, .hotelsCompleted, .hotelsFailed),
                payload: ["location": location.name],
                logger: logger
            )
            return wire.toDomain()
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
            if await counter.incrementAndGet() == 1 {
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
