// HTTPMethod.swift
// Typed HTTP method + header primitives. Replaces raw strings like
// `request.httpMethod = "GET"` so the "GET" vs "Get" vs "get" typo class
// is impossible by construction.

import Foundation

/// HTTP request methods, typed.
enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Common HTTP header field names.
enum HTTPHeader: String, Sendable {
    case contentType = "Content-Type"
    case accept = "Accept"
    case authorization = "Authorization"
}

/// Common content-type values.
enum ContentType: String, Sendable {
    case json = "application/json"
    case formURLEncoded = "application/x-www-form-urlencoded"
}

extension URLRequest {
    /// Type-safe alternative to assigning `httpMethod` as a raw string.
    mutating func setMethod(_ method: HTTPMethod) {
        self.httpMethod = method.rawValue
    }

    /// Sets a header field by typed name.
    mutating func setHeader(_ header: HTTPHeader, _ value: String) {
        self.setValue(value, forHTTPHeaderField: header.rawValue)
    }

    /// Sets `Content-Type` to the given typed content type.
    mutating func setContentType(_ contentType: ContentType) {
        self.setHeader(.contentType, contentType.rawValue)
    }
}
