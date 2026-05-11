// FailableDecodable.swift
// Per-element decoding wrapper for collection responses where a single
// malformed wire row from the API shouldn't tear down the entire array.
//
// Use case: the autocomplete `[Place]` and hotels `[Hotel]` responses are
// top-level / nested arrays from the staging API. A single row with a
// type-mismatched field (e.g. `id` arrives as a String instead of an Int,
// or a non-optional field is `null`) would propagate `DecodingError` out
// of the wrapping array decode, dropping ALL N rows. That's a poor UX
// tradeoff — the user pays for one bad data row by seeing zero results.
//
// `FailableDecodable<T>` decodes individually and surfaces malformed rows
// as `nil`. The caller uses `compactMap(\.value)` (or the `.compactValues`
// extension below) to filter survivors.

import Foundation

/// Decodes `Wrapped` but turns any decode failure into `nil` on `value`.
/// Pair with `[FailableDecodable<T>]` + `.compactValues` to lossily
/// decode an array of `T`.
struct FailableDecodable<Wrapped: Decodable>: Decodable {
    let value: Wrapped?

    init(from decoder: Decoder) throws {
        do {
            self.value = try Wrapped(from: decoder)
        } catch {
            self.value = nil
        }
    }
}

extension Array {
    /// Convenience for arrays of `FailableDecodable<T>` — returns the
    /// non-nil `.value`s in order.
    func compactValues<T>() -> [T] where Element == FailableDecodable<T> {
        compactMap(\.value)
    }
}

extension JSONDecoder {
    /// Decodes `[T]` from `data` and silently drops any element whose
    /// per-element decode threw. Returns only the elements that succeeded.
    ///
    /// Use this for API responses where the array represents independent
    /// records (autocomplete results, hotel listings) and partial
    /// availability is preferable to total failure.
    func decodeLossy<T: Decodable>(_ type: [T].Type, from data: Data) throws -> [T] {
        try decode([FailableDecodable<T>].self, from: data).compactValues()
    }
}

extension KeyedDecodingContainer {
    /// Lossy variant for nested arrays — decodes `[T]` for `key` and drops
    /// any element whose per-element decode threw. Returns `[]` when the
    /// key is absent.
    ///
    /// Mirrors `JSONDecoder.decodeLossy` for the case where the array
    /// lives inside a wire object (`{ "hotels": [...] }`) instead of at
    /// the top level.
    func decodeLossyArray<T: Decodable>(_ type: [T].Type, forKey key: Key) throws -> [T] {
        try decodeIfPresent([FailableDecodable<T>].self, forKey: key)?.compactValues() ?? []
    }
}
