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

// MARK: - Error model

enum NetworkingError: Error, Sendable {
    case invalidResponse
    case status(Int)
    case decode(DecodingError)
}

extension NetworkingError: LocalizedError, CustomStringConvertible {
    var errorDescription: String? { description }
    var description: String {
        switch self {
        case .invalidResponse:
            return "Non-HTTP response"
        case .status(let code):
            return "HTTP \(code)"
        case .decode(let underlying):
            return "Decode failed: \(underlying)"
        }
    }
}

// MARK: - Cancellation translation

extension Error {
    /// Translates URLSession's `URLError(.cancelled)` to `CancellationError`,
    /// the conventional Swift Concurrency cancellation type. Returns every
    /// other error unchanged. The two clients and the two VMs all need this
    /// translation; defining it once keeps the catch arms uniform.
    func translatingCancellation() -> Error {
        if let urlError = self as? URLError, urlError.code == .cancelled {
            return CancellationError()
        }
        return self
    }
}

// MARK: - Transport orchestration

extension HTTPClient {
    /// Standard transport flow for a JSON endpoint: log-initiated, send,
    /// check cancellation, decode (top-level), check cancellation again,
    /// log-completed. On failure, translates URL-level cancellation to
    /// `CancellationError` and otherwise wraps `DecodingError` in
    /// `NetworkingError.decode` then logs + re-throws.
    ///
    /// Owns the cross-cutting concerns that previously lived inside each
    /// feature client's `.live` factory closure (logging cadence,
    /// cancellation translation, post-decode cancel check).
    func executeJSON<T: Decodable>(
        _ request: URLRequest,
        as type: T.Type,
        event: (initiated: LogEvent, completed: LogEvent, failed: LogEvent),
        payload: [String: String],
        logger: LogClient
    ) async throws -> T {
        logger.debug(event.initiated, payload)
        do {
            let (data, _) = try await send(request)
            try Task.checkCancellation()
            let value = try Decoders.api.decode(T.self, from: data)
            try Task.checkCancellation()
            logger.info(event.completed, payload)
            return value
        } catch {
            let translated = error.translatingCancellation()
            if translated is CancellationError {
                throw translated
            }
            let surfaced: Error = (translated as? DecodingError).map(NetworkingError.decode) ?? translated
            logger.error(event.failed, ["error": "\(surfaced)"])
            throw surfaced
        }
    }

    /// Variant that delegates decoding to a caller-supplied closure.
    /// Used when the response isn't a single `T.init(from:)` call — e.g.
    /// `decodeLossy([Place].self, from:)` for top-level lossy arrays.
    func executeJSON<T>(
        _ request: URLRequest,
        event: (initiated: LogEvent, completed: LogEvent, failed: LogEvent),
        payload: [String: String],
        logger: LogClient,
        decode: @Sendable (Data) throws -> T
    ) async throws -> T {
        logger.debug(event.initiated, payload)
        do {
            let (data, _) = try await send(request)
            try Task.checkCancellation()
            let value = try decode(data)
            try Task.checkCancellation()
            logger.info(event.completed, payload)
            return value
        } catch {
            let translated = error.translatingCancellation()
            if translated is CancellationError {
                throw translated
            }
            let surfaced: Error = (translated as? DecodingError).map(NetworkingError.decode) ?? translated
            logger.error(event.failed, ["error": "\(surfaced)"])
            throw surfaced
        }
    }
}
