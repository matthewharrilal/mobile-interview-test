// HotelListingsView.swift
// Sectioned editorial layout: parallax location header → filter chip strip →
// curated horizontal carousels per section. Image-bleed cards.
//
// Hosts the transition shell (architect-scaffolded) for three Airbnb-style
// transitions:
//   1. Search-pill blur-crossfade  → SearchActiveOverlay (Worker A)
//   2. Card → detail expansion      → HotelDetailScene  (Worker B)
//   3. Swipe-down dismiss           → HotelDetailScene  (Worker C)
//
// Composition is a ZStack — explore content underneath, search-pill chrome
// floating on top, and conditional overlay layers (search / detail) mounted
// only while their state is active. See ux-research/team/01-integration-plan.md
// for the boundary between the three workers.

import SwiftUI

// MARK: - Body

struct HotelListingsView: View {
    @State private var viewModel: HotelListingsViewModel
    @State private var searchViewModel: SearchViewModel
    @Environment(\.dismiss) private var dismiss

    /// Single matched-geometry namespace for every cross-cutting morph:
    /// "searchPill" (host pill ↔ overlay pill), "card-…" (carousel card ↔
    /// detail hero). One namespace = one morph graph; ids stay distinct.
    @Namespace private var ns

    @State private var selectedFilter: HotelListingsState.Filter = .all
    @State private var presentation: PresentationLayer = .browsing

    /// 0 when detail is fully expanded, 1 when the dismiss-throw completes.
    /// Worker C writes via the `HotelDetailScene` binding; the host reads it
    /// to drive the explore layer's un-blur live as the detail clears.
    @State private var dismissProgress: CGFloat = 0

    init(place: Place, client: HotelsClient = .live()) {
        _viewModel = State(initialValue: HotelListingsViewModel(
            location: place,
            client: client,
            logger: .live
        ))
        // TODO(polish): thread `.live()` SearchClient from ResortPassApp.
        _searchViewModel = State(initialValue: SearchViewModel(
            client: .preview,
            logger: .silent
        ))
    }

    init(viewModel: HotelListingsViewModel) {
        _viewModel = State(initialValue: viewModel)
        _searchViewModel = State(initialValue: SearchViewModel(
            client: .preview,
            logger: .silent
        ))
    }

    /// Three discrete top-level layers. The base layer is always mounted;
    /// the other two are conditional and host their own surfaces.
    enum PresentationLayer: Equatable {
        case browsing
        case searchActive
        case detailExpanded(hotel: Hotel, sourceID: String)
    }

    var body: some View {
        ZStack(alignment: .top) {
            exploreContent
                .blur(radius: exploreBlurRadius)
                .opacity(exploreOpacity)
                .allowsHitTesting(presentation == .browsing)

            // Floating search-pill chrome — pinned, never scrolls. Source
            // identity for the "searchPill" matched-geometry. Hidden when
            // the search overlay is up (the overlay carries the matching id).
            if presentation != .searchActive {
                searchPillBar
                    .matchedGeometryEffect(id: "searchPill", in: ns)
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.top, Theme.Spacing.s)
            }

            // Worker A's surface — fills in blur/dim/crossfade.
            if presentation == .searchActive {
                SearchActiveOverlay(
                    viewModel: searchViewModel,
                    ns: ns,
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            presentation = .browsing
                        }
                    }
                )
                .transition(.opacity)
            }

            // Workers B + C surface — fill in matched-geometry + drag.
            if case .detailExpanded(let hotel, let sourceID) = presentation,
               case .loaded(let loaded) = viewModel.state.status {
                HotelDetailScene(
                    hotel: hotel,
                    currency: loaded.currency,
                    ns: ns,
                    sourceID: sourceID,
                    dismissProgress: $dismissProgress,
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            presentation = .browsing
                            dismissProgress = 0
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .background(Theme.Color.background)
        .navigationTitle(viewModel.state.location.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.thinMaterial, for: .navigationBar)
        .toolbar(presentation == .browsing ? .visible : .hidden, for: .navigationBar)
        .onAppear { viewModel.send(.appeared) }
        .onChange(of: selectedFilter) { _, new in
            viewModel.send(.filterChanged(new))
        }
    }

    /// Blur applied to the explore layer. Ramps in proportional to how
    /// "expanded" the detail layer is (1 - dismissProgress while the layer
    /// is mounted; otherwise 0). Worker B can re-tune the 24pt ceiling.
    private var exploreBlurRadius: CGFloat {
        guard case .detailExpanded = presentation else { return 0 }
        return (1 - dismissProgress) * 24
    }

    /// Dim applied to the explore layer alongside the blur. Same logic —
    /// Worker B refines the 0.5 floor.
    private var exploreOpacity: Double {
        guard case .detailExpanded = presentation else { return 1.0 }
        return 1.0 - (1.0 - Double(dismissProgress)) * 0.5
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

// MARK: - Search pill (host source)

private extension HotelListingsView {
    /// Pill that matches the search bar inside `SearchActiveOverlay`. Tapping
    /// commits the `searchActive` state through the view's intent system
    /// equivalent here (a SwiftUI `withAnimation` envelope around state mutation).
    var searchPillBar: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                presentation = .searchActive
            }
        } label: {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: Theme.Icon.search)
                    .foregroundStyle(Theme.Color.textTertiary)
                Text("Search hotels")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Color.textSecondary)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s + 2)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.l))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.l)
                    .stroke(Theme.Color.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Search hotels"))
        .accessibilityAddTraits(.isSearchField)
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
        .refreshable { viewModel.send(.retryTapped) }
        .transition(.opacity)
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
                withAnimation(.snappy(duration: 0.25)) {
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
        .transition(.opacity.combined(with: .move(edge: .top)))
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
                    .frame(width: proxy.size.width, height: 360 + stretch)
                    .offset(y: -stretch / 2 - parallax)
                    .scaleEffect(1.0 + (stretch / 2400.0), anchor: .center)  // subtle ken-burns on pull
                    .clipped()

                // Top edge softener — fades from the page background into
                // the photo so the top line never reads as a hard cut against
                // the chrome (especially when overscrolling exposes the area
                // above the image).
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
            .frame(width: proxy.size.width, height: 360)   // taller than before to absorb safe-area extension
            .clipped()
        }
        .frame(height: 360)
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
                    .frame(height: 0.5)
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
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    presentation = .detailExpanded(hotel: hotel, sourceID: sourceID)
                                }
                            }
                        )
                        .matchedGeometryEffect(id: sourceID, in: ns)
                        .contextMenu {
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    presentation = .detailExpanded(hotel: hotel, sourceID: sourceID)
                                }
                            } label: {
                                Label("View details", systemImage: "info.circle")
                            }
                        } preview: {
                            HotelDetailPreview(hotel: hotel, currency: currency)
                        }
                        // iOS 17 peek-carousel: cards at edges scale + fade.
                        .scrollTransition(.animated, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1.0 : 0.94, anchor: .center)
                                .opacity(phase.isIdentity ? 1.0 : 0.7)
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
        .transition(.opacity)
    }

    func failedState(_ message: String) -> some View {
        ContentUnavailableView {
            Label(Strings.Hotels.failedHeadline, systemImage: Theme.Icon.warning)
                .foregroundStyle(Theme.Color.danger)
        } description: {
            Text(message)
        } actions: {
            Button(Strings.Search.tryAgain) { viewModel.send(.retryTapped) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Color.accent)
        }
        .transition(.opacity)
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
