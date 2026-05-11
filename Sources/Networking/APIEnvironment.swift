// APIEnvironment.swift
// Single source of truth for the API base URL across build configurations.
//
// Modeled as a `struct` (not a single-case enum) so adding `.production`
// or per-environment overrides (timeout, feature flags) doesn't require
// rewriting consumers. `.staging` is the only ships-today static factory
// — see ADR-003 / README "Future improvements" for the production hook.

import Foundation

struct APIEnvironment: Sendable, Equatable {
    let baseURL: URL

    /// Staging — the only environment exposed to the take-home. Force-unwrap
    /// safety: the literal URL is compile-time-verifiable and parses.
    static let staging = APIEnvironment(baseURL: URL(string: "https://staging-app.resortpass.com")!)
}
