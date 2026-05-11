// ErrorKind.swift
// Coarse classification of errors for user-facing messaging.
// Both Search and HotelListings VMs collapse caught errors through `from(_:)`
// to pick the right localized string — keeps the per-feature catch blocks
// short and the mapping rule in one place.

import Foundation

enum ErrorKind: Sendable, Equatable {
    /// No internet path available, or connection dropped mid-request.
    case notConnected
    /// Request didn't complete in time.
    case timeout
    /// Server reachable but returned 5xx.
    case serverError
    /// Response decoded into our types failed — schema drift or corrupt payload.
    case decodeError
    /// Anything we don't have a tailored message for.
    case unknown

    static func from(_ error: Error) -> ErrorKind {
        if error is DecodingError {
            return .decodeError
        }
        if let networkingError = error as? NetworkingError {
            switch networkingError {
            case .status(let code):
                return (500...599).contains(code) ? .serverError : .unknown
            case .invalidResponse:
                return .unknown
            case .decode:
                return .decodeError
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
                 .internationalRoamingOff, .callIsActive:
                return .notConnected
            case .timedOut:
                return .timeout
            default:
                return .unknown
            }
        }
        return .unknown
    }

    /// Whether retrying the same request is likely to recover. Transient
    /// network conditions and 5xx are retryable; decode errors and unknown
    /// failures are not (retry would hit the same path).
    var isRetryable: Bool {
        switch self {
        case .notConnected, .timeout, .serverError: return true
        case .decodeError, .unknown:                return false
        }
    }
}

// MARK: - User-facing copy mapping

/// Bundles the five user-facing strings a feature needs for each
/// `ErrorKind`. Replaces the duplicated 5-arm switch that previously
/// lived as a private static `message(for:)` in each ViewModel.
struct ErrorMessages: Sendable {
    let notConnected: String
    let timeout: String
    let serverError: String
    let decodeError: String
    let unknown: String

    func message(for kind: ErrorKind) -> String {
        switch kind {
        case .notConnected: return notConnected
        case .timeout:      return timeout
        case .serverError:  return serverError
        case .decodeError:  return decodeError
        case .unknown:      return unknown
        }
    }
}
