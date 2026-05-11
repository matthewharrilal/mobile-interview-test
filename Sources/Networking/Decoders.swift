// Decoders.swift
// Configured JSONDecoder + JSONEncoder used for every networking call.
// Uses .useDefaultKeys (NOT .convertFromSnakeCase) so wire-level fields like
// objectID, queryID, indexName decode cleanly via explicit CodingKeys per type.

import Foundation

enum Decoders {
    static let api: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

enum Encoders {
    /// Mirrors `Decoders.api` so encode→decode round-trips share strategy.
    static let api: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .useDefaultKeys
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
