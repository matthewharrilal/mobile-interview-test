// ResortPassApp.swift
// App entry point. Composes the root view with .live client wiring.
// In DEBUG, supports launch arguments to inject failing/empty clients
// for Maestro flows that exercise failure-state UIs without taking down staging:
//   --ui-test-fail-search                → SearchClient.failing
//   --ui-test-fail-hotels                → HotelsClient.failing
//   --ui-test-empty-hotels               → HotelsClient returns empty results
//   --ui-test-toggle-recovery-on-retry   → modifier: when paired with a -fail-* flag,
//                                          uses .failingThenRecovers (fails first call,
//                                          succeeds afterward) so retry-recovery is testable

import SwiftUI

@main
struct ResortPassApp: App {
    /// Shared status-bar animator. Lives on the App so the bridge HC
    /// reference is stable across scene-phase changes (the iOS 17 morph
    /// path in `HotelListingsView` reaches it via
    /// `@Environment(\.statusBarStyleAnimator)`). On iOS 18 the
    /// `.zoom` transition coordinates the status bar natively, so call
    /// sites gate the animator and it stays a no-op there.
    @State private var statusBarAnimator = StatusBarStyleAnimator()

    /// Shared UIKit transition adapter for the iOS 17 fallback path.
    /// Vends `MorphPresentationController`, `MorphAnimatedTransitioning`,
    /// and `MorphInteractionController` behind a single
    /// `UIViewControllerTransitioningDelegate`. Reachable from call sites
    /// via `@Environment(\.morphTransitionAdapter)`. iOS 18's
    /// `.navigationTransition(.zoom)` is the active morph on that path,
    /// so the adapter sits idle there — its API is consumed only by the
    /// iOS 17 supplemental migration path.
    @State private var morphTransitionAdapter = MorphTransitionAdapter()

    /// The single composition-root dependency graph. Built once here
    /// from `AppDependencies.live()` (or DEBUG-overridden by launch
    /// arguments for Maestro UI test paths). All downstream code reads
    /// dependencies from this value — either via constructor injection
    /// at the VM seam or `@Environment(\.dependencies)` for ad-hoc
    /// access at the view layer.
    @State private var dependencies: AppDependencies
    @State private var searchViewModel: SearchViewModel

    init() {
        // Build the live dependency graph, then DEBUG-only override
        // specific clients based on launch arguments so Maestro can
        // exercise failure UIs without restarting the staging API.
        var deps = AppDependencies.live()
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "ui-test-fail-search") {
            deps.search = UserDefaults.standard.bool(forKey: "ui-test-toggle-recovery-on-retry")
                ? .failingThenRecovers
                : .failing
        }
        if UserDefaults.standard.bool(forKey: "ui-test-fail-hotels") {
            deps.hotels = UserDefaults.standard.bool(forKey: "ui-test-toggle-recovery-on-retry")
                ? .failingThenRecovers
                : .failing
        }
        if UserDefaults.standard.bool(forKey: "ui-test-empty-hotels") {
            deps.hotels = HotelsClient { _ in
                HotelsSearchResponse(hotels: [], currency: .usd, total: 0)
            }
        }
        #endif
        _dependencies = State(initialValue: deps)
        _searchViewModel = State(initialValue: SearchViewModel(
            client: deps.search,
            logger: deps.logger
        ))
    }

    var body: some Scene {
        WindowGroup {
            // The status-bar bridge is only needed on the iOS 17 fallback
            // path. iOS 18's `.navigationTransition(.zoom)` coordinates
            // the system status bar natively, so the
            // `UIViewControllerRepresentable` wrapper would only add
            // sizing-resolution overhead (and was observed to mis-size
            // the inner SwiftUI tree by leaking iPad-default bounds onto
            // an iPhone screen). Gate it on the deployment target's
            // lowest fallback path.
            if #available(iOS 18.0, *) {
                rootContent
            } else {
                StatusBarBridgedRoot(animator: statusBarAnimator) {
                    rootContent
                }
                .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        RootNavigationView(
            searchViewModel: searchViewModel,
            hotelsClient: dependencies.hotels
        )
        .environment(\.dependencies, dependencies)
        .environment(\.statusBarStyleAnimator, statusBarAnimator)
        .environment(\.morphTransitionAdapter, morphTransitionAdapter)
    }
}

// MARK: - Root navigation host

/// Owns the shared zoom-transition `@Namespace`. Must be a View (not the App
/// itself) so the namespace lives in a body that re-emits both the source
/// (card in HotelListingsView) and the destination (HotelDetailScene). The
/// iOS 18 `.matchedTransitionSource` + `.navigationTransition(.zoom)` pair
/// requires a single namespace shared across both ends of the morph.
///
/// On iOS 17 the namespace is unused — the listings view falls back to its
/// internal matchedGeometryEffect + ZStack overlay path.
private struct RootNavigationView: View {
    let searchViewModel: SearchViewModel
    let hotelsClient: HotelsClient

    @Namespace private var zoomNamespace

    var body: some View {
        NavigationStack(
            path: Binding(
                get: { searchViewModel.state.path },
                set: { searchViewModel.send(.pathChanged($0)) }
            )
        ) {
            SearchView(viewModel: searchViewModel)
                .navigationDestination(for: AppDestination.self) { destination in
                    switch destination {
                    case .hotelListings(let place):
                        HotelListingsView(
                            place: place,
                            client: hotelsClient,
                            zoomNamespace: zoomNamespace,
                            pushDetail: { hotel, sourceID, currency in
                                searchViewModel.send(.pathChanged(
                                    searchViewModel.state.path + [.hotelDetail(hotel: hotel, sourceID: sourceID, currency: currency)]
                                ))
                            }
                        )
                    case .hotelDetail(let hotel, let sourceID, let currency):
                        // Pushed-mode detail (iOS 18+ path). Receives the same
                        // namespace as the source card so `.zoom(sourceID:in:)`
                        // can match. iOS 17 never produces this case.
                        HotelDetailScene(
                            hotel: hotel,
                            currency: currency,
                            presentationStyle: .pushed
                        )
                        .modifier(ZoomTransitionIfAvailable(sourceID: sourceID, namespace: zoomNamespace))
                    }
                }
        }
    }
}

// MARK: - Conditional zoom transition modifier

/// Applies `.navigationTransition(.zoom(sourceID:in:))` on iOS 18+, no-op on
/// iOS 17. The iOS 17 path never reaches this modifier (the listings view
/// uses its ZStack-overlay fallback instead of pushing `.hotelDetail`), but
/// the gate is required for the file to compile against the iOS 17 SDK.
struct ZoomTransitionIfAvailable: ViewModifier {
    let sourceID: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            content
        }
    }
}
