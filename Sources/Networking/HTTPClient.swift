// HTTPClient.swift
// Shared transport — every Client routes through this so authentication, status
// validation, and timeout policy live in one place.

import Foundation

struct HTTPClient: Sendable {
    var send: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension HTTPClient {
    static func live(session: URLSession = .shared) -> HTTPClient {
        HTTPClient { request in
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw NetworkingError.invalidResponse
            }
            guard Networking.Constants.successStatusRange.contains(http.statusCode) else {
                throw NetworkingError.status(http.statusCode)
            }
            return (data, http)
        }
    }
}

enum NetworkingError: Error, Sendable {
    case invalidResponse
    case status(Int)
}
