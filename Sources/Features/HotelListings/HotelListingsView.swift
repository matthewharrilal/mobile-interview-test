// HotelListingsView.swift
// Sectioned editorial layout: parallax location header → filter chip strip →
// curated horizontal carousels per section. Image-bleed cards.

import SwiftUI

// MARK: - Body

struct HotelListingsView: View {
    @State private var viewModel: HotelListingsViewModel
    @Environment(\.dismiss) private var dismiss
    @Namespace private var heroNamespace
    @State private var selectedFilter: HotelListingsState.Filter = .all
    @State private var presentedHotel: Hotel?

    init(place: Place, client: HotelsClient = .live()) {
        _viewModel = State(initialValue: HotelListingsViewModel(
            location: place,
            client: client,
            logger: .live
        ))
    }

    init(viewModel: HotelListingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
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
        .background(Theme.Color.background)
        .navigationTitle(viewModel.state.location.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.thinMaterial, for: .navigationBar)
        .onAppear { viewModel.send(.appeared) }
        .onChange(of: selectedFilter) { _, new in
            viewModel.send(.filterChanged(new))
        }
        .sheet(item: $presentedHotel) { hotel in
            if case .loaded(let loaded) = viewModel.state.status {
                HotelDetailSheet(hotel: hotel, currency: loaded.currency)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
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
                ForEach(loaded.sections) { section in
                    sectionView(section, currency: loaded.currency)
                }
                Spacer().frame(height: Theme.Spacing.xl)
            }
        }
        .coordinateSpace(name: "scroll")
        .refreshable { viewModel.send(.retryTapped) }
        .transition(.opacity)
    }

    func parallaxHeader(loaded: HotelListingsState.Loaded) -> some View {
        let firstURL = loaded.hotels.first?.imageURL
        return GeometryReader { proxy in
            let offset = proxy.frame(in: .named("scroll")).minY
            let stretch = max(0, offset)
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: firstURL)
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: 280 + stretch)
                    .offset(y: -stretch)
                    .clipped()

                LinearGradient(
                    colors: [Color.black.opacity(0.65), Color.black.opacity(0.0), Color.black.opacity(0.0)],
                    startPoint: .bottom,
                    endPoint: .top
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
        }
        .frame(height: 280)
    }

    func headerSummary(loaded: HotelListingsState.Loaded) -> String {
        let count = loaded.hotels.count
        let cheapest = loaded.hotels.compactMap(\.cheapestPrice).min() ?? 0
        return "\(count) hotels · from \(loaded.currency.symbol)\(Int(cheapest))"
    }

    func sectionView(_ section: HotelListingsState.Section, currency: Currency) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
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
            .padding(.horizontal, Theme.Spacing.m)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.m) {
                    ForEach(section.hotels) { hotel in
                        CompactHotelCard(
                            hotel: hotel,
                            currency: currency,
                            onTap: { presentedHotel = hotel }
                        )
                        .matchedGeometryEffect(id: "card-\(section.id)-\(hotel.id)", in: heroNamespace)
                        .contextMenu {
                            Button { presentedHotel = hotel } label: {
                                Label("View details", systemImage: "info.circle")
                            }
                        } preview: {
                            HotelDetailPreview(hotel: hotel, currency: currency)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.s)
            }
        }
        .padding(.top, Theme.Spacing.l)
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

// MARK: - Detail sheet + preview

struct HotelDetailSheet: View {
    let hotel: Hotel
    let currency: Currency

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                HotelImageCarousel(
                    urls: hotel.imageURLs,
                    hotelName: hotel.name,
                    hotelStar: hotel.hotelStar
                )
                .frame(height: 280)

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    if let location = hotel.displayLocation {
                        Text(location.uppercased())
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .tracking(1.3)
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                    Text(hotel.name)
                        .font(Theme.Typography.editorialDisplay)
                        .foregroundStyle(Theme.Color.textPrimary)
                    if let rating = hotel.rating, rating > 0 {
                        HStack(spacing: 6) {
                            StarRating(value: rating, size: 14)
                            Text(String(format: "%.1f", rating))
                                .font(.system(.subheadline, design: .serif).weight(.medium).monospacedDigit())
                            if hotel.reviewCount > 0 {
                                Text("(\(hotel.reviewCount) reviews)")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.Color.textSecondary)
                            }
                        }
                    }
                }

                Divider()

                if let product = hotel.productName {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("Available today")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .tracking(1.0)
                            .foregroundStyle(Theme.Color.textTertiary)
                        Text(product)
                            .font(.system(.title3, design: .serif).weight(.medium))
                            .foregroundStyle(Theme.Color.textPrimary)
                        if let price = hotel.cheapestPrice {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("from")
                                    .font(.system(.body, design: .serif).italic())
                                    .foregroundStyle(Theme.Color.textTertiary)
                                Text("\(currency.symbol)\(Int(price))")
                                    .font(.system(.title, design: .serif).weight(.semibold).monospacedDigit())
                                    .foregroundStyle(Theme.Color.textPrimary)
                            }
                        }
                    }
                }
            }
            .padding(Theme.Spacing.l)
        }
        .background(Theme.Color.background)
    }
}

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
