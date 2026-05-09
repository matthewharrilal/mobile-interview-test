// Decoders.swift
// Single configured JSONDecoder for every networking call.
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
