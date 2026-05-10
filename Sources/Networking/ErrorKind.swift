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
}
