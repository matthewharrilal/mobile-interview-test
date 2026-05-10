// HotelListingsView.swift
// SwiftUI view for the HotelListings screen — editorial hotel cards with
// large hero carousel, gradient name overlay, refined serif typography.

import SwiftUI

// MARK: - Body

struct HotelListingsView: View {
    @State private var viewModel: HotelListingsViewModel
    @Environment(\.dismiss) private var dismiss

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
        .onAppear { viewModel.send(.appeared) }
    }
}

// MARK: - Subviews

private extension HotelListingsView {
    var loadingState: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.l) {
                ForEach(0..<3, id: \.self) { _ in
                    skeletonCard
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
        }
        .accessibilityLabel(Text("Loading hotels"))
    }

    var skeletonCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Rectangle()
                .fill(Theme.Color.surfaceRecessed)
                .aspectRatio(4/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.l))
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                RoundedRectangle(cornerRadius: Theme.CornerRadius.s)
                    .fill(Theme.Color.surfaceRecessed)
                    .frame(height: 14)
                    .frame(maxWidth: 160)
                RoundedRectangle(cornerRadius: Theme.CornerRadius.s)
                    .fill(Theme.Color.surfaceRecessed)
                    .frame(height: 12)
                    .frame(maxWidth: 100)
            }
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.s)
        }
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.l))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.l)
                .stroke(Theme.Color.border, lineWidth: 0.5)
        )
    }

    func loadedState(_ loaded: HotelListingsState.Loaded) -> some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.l) {
                ForEach(loaded.hotels) { hotel in
                    HotelCard(hotel: hotel, currency: loaded.currency, onTap: nil)
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
        }
        .refreshable { viewModel.send(.retryTapped) }
        .transition(.opacity)
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

// MARK: - Accessibility

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

#Preview("Loaded — Dark") {
    NavigationStack {
        HotelListingsView(viewModel: HotelListingsViewModel(
            location: Place(placeID: 1, objectID: "Newport", name: "Newport Beach, California",
                            type: "city", cityName: "Newport Beach", stateCode: "CA", countryCode: "US",
                            latitude: 33.6, longitude: -117.9),
            client: .preview
        ))
    }
    .preferredColorScheme(.dark)
}
