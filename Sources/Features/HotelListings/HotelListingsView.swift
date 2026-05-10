// HotelListingsView.swift
// Sectioned editorial layout: parallax location header → filter chip strip →
// curated horizontal carousels per section. Image-bleed cards.
//
// Listings is a terminal destination of the search flow — the user lands
// here after picking a place; the only re-search affordance is the nav back
// chevron. No search pill on this screen.
//
// Hosted transition: card → detail expansion (matched-geometry + drag
// dismiss). Composition is a ZStack — explore content underneath, the
// detail scene mounted only while expanded.

import SwiftUI

// MARK: - Body

struct HotelListingsView: View {
    @State private var viewModel: HotelListingsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// Bridge to the custom `UIHostingController` owning
    /// `preferredStatusBarStyle`. Invoked on the iOS 17 fallback morph
    /// path (matchedGeometryEffect + ZStack overlay) so the status bar
    /// transitions to `.lightContent` over the dark detail hero on the
    /// same envelope as the morph spring, then back to `.darkContent`
    /// on dismiss. iOS 18's `.zoom` transition handles status-bar
    /// coordination natively — call sites gate on `useZoomTransitionPath`
    /// so the animator stays a no-op there.
    @Environment(\.statusBarStyleAnimator) private var statusBarAnimator

    /// iOS 17 matched-geometry namespace for the card ↔ detail morph (ZStack
    /// overlay path). Card sources use ids "card-<section>-<hotel>".
    /// Used as the fallback when iOS 18's `.matchedTransitionSource` is
    /// unavailable.
    @Namespace private var ns

    /// iOS 18+ shared zoom namespace, supplied by `RootNavigationView` so it
    /// spans both the card source (here) and the pushed destination
    /// (`HotelDetailScene` in `.pushed` mode). `nil` when the listings view
    /// is hosted outside the navigation root (e.g. previews) — the iOS 17
    /// fallback path is used in that case.
    private let externalZoomNamespace: Namespace.ID?

    /// iOS 18+ push closure. Called instead of `.cardTapped` when the iOS 18
    /// path is available so the detail is pushed onto the NavigationStack
    /// (where `.navigationTransition(.zoom)` runs the system morph). `nil`
    /// for previews / standalone hosts — falls back to the iOS 17 overlay.
    private let pushDetail: ((Hotel, String, Currency) -> Void)?

    @State private var selectedFilter: HotelListingsState.Filter = .all

    /// Hero parallax height. Scales with Dynamic Type so the editorial
    /// headline + summary line continue to fit cleanly above the bottom
    /// scrim at xxLarge and beyond. Anchored at 360 pt at default size
    /// to preserve the existing visual rhythm.
    @ScaledMetric(relativeTo: .title) private var heroHeight: CGFloat = 360

    init(
        place: Place,
        client: HotelsClient = .live(),
        zoomNamespace: Namespace.ID? = nil,
        pushDetail: ((Hotel, String, Currency) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: HotelListingsViewModel(
            location: place,
            client: client,
            logger: .live
        ))
        self.externalZoomNamespace = zoomNamespace
        self.pushDetail = pushDetail
    }

    init(
        viewModel: HotelListingsViewModel,
        zoomNamespace: Namespace.ID? = nil,
        pushDetail: ((Hotel, String, Currency) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.externalZoomNamespace = zoomNamespace
        self.pushDetail = pushDetail
    }

    /// True when the iOS 18 push-based detail path is available AND wired
    /// up by the host. False on iOS 17 or when no push closure was supplied
    /// (previews) — the ZStack-overlay morph runs instead.
    private var useZoomTransitionPath: Bool {
        guard pushDetail != nil, externalZoomNamespace != nil else { return false }
        if #available(iOS 18.0, *) { return true }
        return false
    }

    /// Binding that surfaces `state.dismissProgress` to descendants (e.g.
    /// `HotelDetailScene`) while routing every write through `send(_:)` so
    /// the MVI invariant holds. T-002 will use this binding from the
    /// DragGesture on the detail hero.
    private var dismissProgressBinding: Binding<CGFloat> {
        Binding(
            get: { viewModel.state.dismissProgress },
            set: { viewModel.send(.dragProgressChanged(progress: $0)) }
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            exploreContent
                .blur(radius: exploreBlurRadius)
                .opacity(exploreOpacity)
                .allowsHitTesting(viewModel.state.presentation == .browsing)

            // Detail surface — fills in matched-geometry + drag.
            // The matched-geometry hero inside HotelDetailScene carries the
            // visible morph; the surface itself uses opacity-only as its
            // mount/unmount transition (driving the morph through `.scale`
            // would double-animate the geometry). The spring envelope on the
            // state mutation governs the timing — see `withAnimation` calls
            // on the card tap and `onDismiss` below.
            if case .detailExpanded(let hotel, let sourceID) = viewModel.state.presentation,
               case .loaded(let loaded) = viewModel.state.status {
                HotelDetailScene(
                    hotel: hotel,
                    currency: loaded.currency,
                    ns: ns,
                    sourceID: sourceID,
                    dismissProgress: dismissProgressBinding,
                    onDismiss: { throwVelocity in
                        // Scale morph spring response by throw vigor so a
                        // fast flick dismisses faster than a slow drag —
                        // closest declarative approximation of velocity
                        // injection (cohesion-animation-system B-3 fix).
                        // > 800 pt/s = clearly thrown → 1.4× speed.
                        let speed: Double = throwVelocity > 800 ? 1.4 : 1.0
                        withAnimation(Theme.Animation.morphSpring.speed(speed)) {
                            viewModel.send(.detailDismissed)
                        }
                        // iOS 17 dismiss: transition status bar back to
                        // `.darkContent` over the same envelope as the
                        // morph spring (Theme.Animation.morphSpring's
                        // 0.25s response, scaled by `speed` so a thrown
                        // dismiss snaps in lock-step with the spring).
                        // The ZStack overlay path is iOS 17-only — when
                        // the iOS 18 `.zoom` path is active, presentation
                        // never reaches `.detailExpanded` and this
                        // closure isn't reachable.
                        statusBarAnimator.setStyle(.darkContent, duration: Theme.Animation.morphResponseSeconds / speed)
                    }
                )
                // Re-tap forces a fresh identity so an in-flight dismiss
                // of the previous detail is replaced immediately rather
                // than cross-fading (prevents triple-hero ghosting).
                .id(sourceID)
                // Bind the transition's curve to the morph spring envelope
                // so the surface fade lands with the geometry instead of
                // running on SwiftUI's default 350ms ease.
                .transition(.opacity.animation(Theme.Animation.morphSpring))
            }
        }
        .background(Theme.Color.background)
        .navigationTitle(viewModel.state.location.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.thinMaterial, for: .navigationBar)
        .toolbar(viewModel.state.presentation == .browsing ? .visible : .hidden, for: .navigationBar)
        // Bind the toolbar visibility transition to the morph spring so chrome
        // fades on the same envelope as the geometry instead of UIKit's default
        // 0.3s easeInOut (cohesion-rendering-pipeline N-1 fix).
        .animation(Theme.Animation.morphSpring, value: viewModel.state.presentation)
        .onAppear { viewModel.send(.appeared) }
        .onChange(of: selectedFilter) { _, new in
            withAnimation(Theme.Animation.selectionFeedback) {
                viewModel.send(.filterChanged(new))
            }
        }
    }

    /// Blur applied to the explore layer (iOS 17 overlay path only —
    /// the iOS 18 zoom transition handles its own backdrop chrome).
    /// Engaged whenever the detail is expanded so the listings recede
    /// during the forward morph too, not just during dismiss. Earlier
    /// behavior (dismiss-only) caused the source layer to read at full
    /// fidelity through the morphing detail (Phase A #6 revision).
    private var exploreBlurRadius: CGFloat {
        guard case .detailExpanded = viewModel.state.presentation else { return 0 }
        let progress = viewModel.state.dismissProgress
        // Full blur during forward morph (progress = 0); ramps back to 0
        // as the dismiss completes (progress → 1).
        return (1 - progress) * 24
    }

    /// Dim applied to the explore layer (iOS 17 overlay path only).
    /// Floor of 0.7 during forward morph keeps the matched-geometry
    /// source perceptually present without blocking zoom's source
    /// dissolve on iOS 18 (where presentation never leaves `.browsing`,
    /// so this returns 1.0 and the system zoom takes over). Dismiss
    /// ramps the opacity back up to 1.0 as `dismissProgress` → 1.
    private var exploreOpacity: Double {
        guard case .detailExpanded = viewModel.state.presentation else { return 1.0 }
        let progress = viewModel.state.dismissProgress
        // 0.7 at full forward morph (progress = 0), 1.0 at dismiss complete.
        return 0.7 + (1.0 - 0.7) * Double(progress)
    }

    /// Routes the card tap to either the iOS 18 push-based detail (system
    /// `.zoom` transition runs automatically) or the iOS 17 ZStack-overlay
    /// morph (driven by `withAnimation(Theme.Animation.morphSpring)`).
    private func handleCardTap(hotel: Hotel, sourceID: String, currency: Currency) {
        if useZoomTransitionPath, let pushDetail {
            // iOS 18 path: NavigationStack pushes; system zoom plays.
            // No `withAnimation` — the zoom envelope is system-owned.
            pushDetail(hotel, sourceID, currency)
        } else {
            // iOS 17 path: existing overlay morph driven by morphSpring.
            withAnimation(Theme.Animation.morphSpring) {
                viewModel.send(.cardTapped(hotel: hotel, sourceID: sourceID))
            }
            // Synchronize the system status bar with the morph: the dark
            // detail hero materializes over the duration of the spring's
            // response window, so flip to `.lightContent` on the same
            // envelope. iOS 18's `.zoom` path coordinates this natively
            // — the gate above ensures we only run the bridge when the
            // overlay morph is actually playing.
            statusBarAnimator.setStyle(.lightContent, duration: Theme.Animation.morphResponseSeconds)
        }
    }
}

// MARK: - Conditional matched-transition source modifier

/// Wraps the iOS-18 `.matchedTransitionSource(id:in:)` (preferred — pairs
/// with `.navigationTransition(.zoom)` on the destination) and falls back
/// to iOS-17 `.matchedGeometryEffect(id:in:)` (the ZStack-overlay morph).
/// `useZoomPath` distinguishes the two paths even when both APIs compile
/// — on iOS 17 the zoom path is unreachable, but on iOS 18 the host might
/// still want the overlay path (e.g. previews without a navigation root).
struct MatchedSourceIfAvailable: ViewModifier {
    let sourceID: String
    let zoomNamespace: Namespace.ID?
    let fallbackNamespace: Namespace.ID
    let useZoomPath: Bool

    func body(content: Content) -> some View {
        if useZoomPath, let zoomNamespace {
            if #available(iOS 18.0, *) {
                content.matchedTransitionSource(id: sourceID, in: zoomNamespace)
            } else {
                content.matchedGeometryEffect(id: sourceID, in: fallbackNamespace)
            }
        } else {
            content.matchedGeometryEffect(id: sourceID, in: fallbackNamespace)
        }
    }
}

// MARK: - Explore content

private extension HotelListingsView {
    var exploreContent: some View {
        Group {
            switch viewModel.state.status {
            case .idle, .loading:
                loadingState
            case .loaded(let loaded):
                loadedState(loaded)
            case .empty:
                emptyState
            case .failed(let message):
                failedState(message)
            }
        }
    }
}

// MARK: - Loaded sectioned layout

private extension HotelListingsView {
    func loadedState(_ loaded: HotelListingsState.Loaded) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                parallaxHeader(loaded: loaded)
                    .padding(.bottom, Theme.Spacing.m)
                FilterChipRow(filters: HotelListingsState.Filter.allCases, selected: $selectedFilter)
                    .padding(.bottom, Theme.Spacing.s)
                if loaded.sections.isEmpty {
                    emptyFilterState(activeFilter: loaded.activeFilter)
                } else {
                    ForEach(loaded.sections) { section in
                        sectionView(section, currency: loaded.currency)
                    }
                }
                Spacer().frame(height: Theme.Spacing.xl)
            }
        }
        .coordinateSpace(name: "scroll")
        .refreshable {
            // Wrap the synchronous `.loading` mutation in the surface
            // crossfade envelope so loadedState's `.transition(.opacity)`
            // removal fires when pull-to-refresh tears the list down
            // (cohesion-animation-system D-Gap, transaction grouping).
            withAnimation(Theme.Animation.surfaceCrossfade) {
                viewModel.send(.retryTapped)
            }
        }
        .transition(.opacity.animation(Theme.Animation.surfaceCrossfade))
        .ignoresSafeArea(edges: .top)         // hero bleeds behind the nav bar
    }

    /// Shown inside the loaded state when the active filter yields zero
    /// matches — keeps the header + chip strip visible so the user can
    /// pivot without leaving the screen.
    func emptyFilterState(activeFilter: HotelListingsState.Filter) -> some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: activeFilter.iconName)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.Color.textTertiary)
                .padding(.top, Theme.Spacing.xl)
            Text("No \(activeFilter.displayName.lowercased()) hotels here")
                .font(Theme.Typography.editorialM)
                .foregroundStyle(Theme.Color.textPrimary)
                .multilineTextAlignment(.center)
            Text("None of the day passes in \(viewModel.state.location.name) match this filter. Try a different one or browse all hotels.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.l)
            Button {
                withAnimation(Theme.Animation.selectionFeedback) {
                    selectedFilter = .all
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Show all hotels")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white)
                .padding(.horizontal, Theme.Spacing.m + 2)
                .padding(.vertical, Theme.Spacing.s + 2)
                .background(
                    Capsule().fill(Theme.Color.accent)
                )
            }
            .padding(.top, Theme.Spacing.s)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .transition(.opacity.combined(with: .move(edge: .top)).animation(Theme.Animation.surfaceCrossfade))
        .accessibilityElement(children: .combine)
    }

    func parallaxHeader(loaded: HotelListingsState.Loaded) -> some View {
        let firstURL = loaded.hotels.first?.imageURL
        return GeometryReader { proxy in
            let offset = proxy.frame(in: .named("scroll")).minY
            let stretch = max(0, offset)               // pull-down stretch
            let parallax = max(0, -offset / 3)         // upward pan as page scrolls
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: firstURL)
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: heroHeight + stretch)
                    .offset(y: -stretch / 2 - parallax)
                    .scaleEffect(1.0 + (stretch / 2400.0), anchor: .center)  // subtle ken-burns on pull
                    .clipped()

                // Top edge softener — fades from the page background into
                // the photo so the top line never reads as a hard cut against
                // the chrome (especially when overscrolling exposes the area
                // above the image). Light mode only: in dark mode the page
                // background resolves to near-black and the gradient becomes
                // a visible darkening band against bright photographic
                // content (see F-T-03), so we skip the softener entirely —
                // modern iOS does not show a hard cut at the safe-area
                // boundary.
                if colorScheme == .light {
                    LinearGradient(
                        stops: [
                            .init(color: Theme.Color.background.opacity(0.85), location: 0.0),
                            .init(color: Theme.Color.background.opacity(0.30), location: 0.06),
                            .init(color: .clear,                                 location: 0.18)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                }

                // Tonal vignette — preserves headline legibility against the photo.
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.25),
                        Color.black.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .allowsHitTesting(false)

                // Bottom scrim — for legibility of the white text overlay
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.65)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.state.location.name.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.9))
                    Text(headerSummary(loaded: loaded))
                        .font(Theme.Typography.editorialDisplay)
                        .foregroundStyle(.white)
                }
                .padding(Theme.Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: proxy.size.width, height: heroHeight)   // taller than before to absorb safe-area extension
            .clipped()
        }
        .frame(height: heroHeight)
    }

    func headerSummary(loaded: HotelListingsState.Loaded) -> String {
        let count = loaded.hotels.count
        let cheapest = loaded.hotels.compactMap(\.cheapestPrice).min() ?? 0
        return "\(count) hotels · from \(loaded.currency.symbol)\(Int(cheapest))"
    }

    func sectionView(_ section: HotelListingsState.Section, currency: Currency) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            // Editorial section header with hairline rule
            HStack(alignment: .center, spacing: Theme.Spacing.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(Theme.Typography.editorialM)
                        .foregroundStyle(Theme.Color.textPrimary)
                    if let subtitle = section.subtitle {
                        Text(subtitle)
                            .font(Theme.Typography.metadata)
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                }
                Spacer()
                Rectangle()
                    .fill(Theme.Color.border)
                    .frame(height: Theme.Spacing.hairline)   // single physical pixel — crisp on @2x and @3x
                    .frame(maxWidth: 60)
            }
            .padding(.horizontal, Theme.Spacing.m)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.l) {   // wider gap so cards don't fuse at edges
                    ForEach(section.hotels) { hotel in
                        let sourceID = "card-\(section.id)-\(hotel.id)"
                        CompactHotelCard(
                            hotel: hotel,
                            currency: currency,
                            onTap: { handleCardTap(hotel: hotel, sourceID: sourceID, currency: currency) }
                        )
                        .modifier(MatchedSourceIfAvailable(
                            sourceID: sourceID,
                            zoomNamespace: externalZoomNamespace,
                            fallbackNamespace: ns,
                            useZoomPath: useZoomTransitionPath
                        ))
                        .contextMenu {
                            Button {
                                handleCardTap(hotel: hotel, sourceID: sourceID, currency: currency)
                            } label: {
                                Label("View details", systemImage: "info.circle")
                            }
                        } preview: {
                            HotelDetailPreview(hotel: hotel, currency: currency)
                        }
                        // iOS 17 peek-carousel: cards at edges scale + fade.
                        // Suppressed during morph (presentation != .browsing)
                        // so the matched-geometry source view starts the morph
                        // from identity rather than mid-scrollTransition scale,
                        // eliminating non-identity source frames during the
                        // 250ms morph window (cohesion-animation-system A+L fix).
                        .scrollTransition(.animated, axis: .horizontal) { content, phase in
                            let suppress = viewModel.state.presentation != .browsing
                            return content
                                .scaleEffect(suppress || phase.isIdentity ? 1.0 : 0.94, anchor: .center)
                                .opacity(suppress || phase.isIdentity ? 1.0 : 0.7)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.top, Theme.Spacing.s)
            }
            .scrollTargetBehavior(.viewAligned)
            .clipped()                                  // prevents card bleed into next section
        }
        .padding(.top, Theme.Spacing.m)                 // tighter section rhythm (was .l = 24, now .m = 16)
    }
}

// MARK: - States

private extension HotelListingsView {
    var loadingState: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                Rectangle()
                    .fill(Theme.Color.surfaceRecessed)
                    .frame(height: 240)
                ForEach(0..<2, id: \.self) { _ in
                    skeletonSection
                }
            }
        }
        .accessibilityLabel(Text("Loading hotels"))
    }

    var skeletonSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.Color.surfaceRecessed)
                .frame(height: 18)
                .frame(maxWidth: 160)
                .padding(.horizontal, Theme.Spacing.m)
            HStack(spacing: Theme.Spacing.m) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.l)
                        .fill(Theme.Color.surfaceRecessed)
                        .frame(width: 220, height: 200)
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
        }
    }

    var emptyState: some View {
        ContentUnavailableView {
            Label(Strings.Hotels.emptyHeadline, systemImage: Theme.Icon.houseSlash)
        } description: {
            Text(String(format: Strings.Hotels.emptyDescriptionFormat, viewModel.state.location.name))
        } actions: {
            Button(Strings.Hotels.backToSearch) { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Color.accent)
        }
        .transition(.opacity.animation(Theme.Animation.surfaceCrossfade))
    }

    func failedState(_ message: String) -> some View {
        ContentUnavailableView {
            Label(Strings.Hotels.failedHeadline, systemImage: Theme.Icon.warning)
                .foregroundStyle(Theme.Color.danger)
        } description: {
            Text(message)
        } actions: {
            Button(Strings.Search.tryAgain) {
                // Same envelope as failedState's `.transition(.opacity)`
                // so the failed view fades out instead of snapping when
                // the user retries (cohesion-animation-system D-Gap).
                withAnimation(Theme.Animation.surfaceCrossfade) {
                    viewModel.send(.retryTapped)
                }
            }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Color.accent)
        }
        .transition(.opacity.animation(Theme.Animation.surfaceCrossfade))
    }
}

// MARK: - Detail preview (context-menu only)

struct HotelDetailPreview: View {
    let hotel: Hotel
    let currency: Currency

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            CachedAsyncImage(url: hotel.imageURL)
                .scaledToFill()
                .frame(width: 280, height: 200)
                .clipped()
            VStack(alignment: .leading, spacing: 6) {
                Text(hotel.name)
                    .font(Theme.Typography.editorialM)
                    .foregroundStyle(Theme.Color.textPrimary)
                if let rating = hotel.rating, rating > 0 {
                    HStack(spacing: 4) {
                        StarRating(value: rating, size: 12)
                        Text(String(format: "%.1f", rating))
                            .font(.system(.footnote, design: .serif).weight(.medium).monospacedDigit())
                    }
                }
                if let price = hotel.cheapestPrice {
                    Text("from \(currency.symbol)\(Int(price))")
                        .font(.system(.headline, design: .serif).weight(.semibold))
                        .foregroundStyle(Theme.Color.textPrimary)
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.m)
        }
        .frame(width: 280)
        .background(Theme.Color.surface)
    }
}

// MARK: - Preview

#Preview("Loaded — Light") {
    NavigationStack {
        HotelListingsView(viewModel: HotelListingsViewModel(
            location: Place(placeID: 1, objectID: "Newport", name: "Newport Beach, California",
                            type: "city", cityName: "Newport Beach", stateCode: "CA", countryCode: "US",
                            latitude: 33.6, longitude: -117.9),
            client: .preview
        ))
    }
}
