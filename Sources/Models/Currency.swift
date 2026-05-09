// Currency.swift
// ISO-4217 currency code with a display symbol for price formatting.

import Foundation

struct Currency: Equatable, Sendable, Hashable, Codable {
    let code: String
    let symbol: String

    static let usd = Currency(code: "USD", symbol: "$")
}
