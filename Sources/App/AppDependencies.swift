// AppDependencies.swift
// Single composition-root value bundling every Sendable client the app
// uses. Eliminates the split between "search client wired in
// ResortPassApp.init" and "hotels client wired in RootNavigationView"
// — now both live in one factory.
//
// **Why this shape (and not a protocol-based registry / DI container):**
// - The 2026-idiomatic Swift Concurrency answer is *function-style*
//   clients: each "service" is a `Sendable struct` whose only fields are
//   `@Sendable async throws` closures. Swap-for-test is one line —
//   `SearchClient { _ in [] }`. No `MockSearchService: SearchService`
//   ceremony per test.
// - Aggregating those structs into `AppDependencies` gives a single
//   identifier-traceable graph: read this file and you see every
//   external dependency the app touches. At 4 clients an SPM container
//   (Factory, Swinject) is pure ceremony cost.
// - Constructor injection STAYS at the boundary (VMs take their
//   specific client, not the whole `AppDependencies`) — that's the
//   separation of concerns. Views that need ad-hoc access reach into
//   `@Environment(\.dependencies)`.
//
// Trade-off documented in case a future hire asks "why not protocols":
// protocols force a separate conformance type per test variant and add
// no expressiveness Swift Concurrency closures don't already provide.

import SwiftUI

@MainActor
struct AppDependencies: Sendable {
    var search: SearchClient
    var hotels: HotelsClient
    var logger: LogClient

    // MARK: - Factories

    /// Production wiring. Composes the live graph: shared logger →
    /// shared HTTP transport (private to the closure since no consumer
    /// reads `dependencies.http` directly) → per-endpoint clients.
    static func live(environment: APIEnvironment = .staging) -> AppDependencies {
        let logger = LogClient.live
        let http = HTTPClient.live()
        return AppDependencies(
            search: .live(environment: environment, http: http, logger: logger),
            hotels: .live(environment: environment, http: http, logger: logger),
            logger: logger
        )
    }

    /// Fixture wiring for previews and unit-style integration tests that
    /// need a complete graph without network. Maestro flows that drive
    /// failure UIs construct ad-hoc variants in `ResortPassApp.init`
    /// (see launchArguments handling).
    static var preview: AppDependencies {
        AppDependencies(
            search: .preview,
            hotels: .preview,
            logger: .silent
        )
    }
}

// MARK: - Environment plumbing

private struct AppDependenciesKey: EnvironmentKey {
    /// Default `.preview` so any view rendered outside the app's root
    /// (e.g. SwiftUI previews) gets fixture data — never accidentally
    /// hits the staging API. Mirrors the same defensive default we
    /// applied to `HotelListingsView.init(client:)`.
    @MainActor static var defaultValue: AppDependencies { .preview }
}

extension EnvironmentValues {
    /// Composition-root dependency graph. Read via
    /// `@Environment(\.dependencies)` in any view that needs ad-hoc
    /// access without prop-drilling.
    var dependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}
