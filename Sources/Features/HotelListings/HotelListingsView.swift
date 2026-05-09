// HotelListingsView.swift
// SwiftUI view for the HotelListings screen — list of hotel cards per Status.

import SwiftUI

// MARK: - Body

struct HotelListingsView: View {
    @Bindable var viewModel: HotelListingsViewModel
    @Environment(\.dismiss) private var dismiss

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
            LazyVStack(spacing: Theme.Spacing.m) {
                ForEach(0..<3, id: \.self) { _ in
                    skeletonCard
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
        }
    }

    var skeletonCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Rectangle()
                .fill(Theme.Color.surfaceRecessed)
                .aspectRatio(16/10, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.m))
            RoundedRectangle(cornerRadius: Theme.CornerRadius.s)
                .fill(Theme.Color.surfaceRecessed)
                .frame(height: 18)
                .frame(maxWidth: 220)
            RoundedRectangle(cornerRadius: Theme.CornerRadius.s)
                .fill(Theme.Color.surfaceRecessed)
                .frame(height: 14)
                .frame(maxWidth: 140)
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.l))
    }

    func loadedState(_ loaded: HotelListingsState.Loaded) -> some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.m) {
                ForEach(loaded.hotels) { hotel in
                    hotelCard(hotel, currency: loaded.currency)
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
        }
    }

    func hotelCard(_ hotel: Hotel, currency: Currency) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            CachedAsyncImage(url: hotel.imageURL)
                .aspectRatio(16/10, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.m))

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(hotel.name)
                        .font(Theme.Typography.titleS)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .lineLimit(2)
                    HStack(spacing: Theme.Spacing.xs) {
                        if let text = hotel.distanceText, !text.isEmpty {
                            Label(text, systemImage: "mappin.circle.fill")
                                .labelStyle(.titleAndIcon)
                        } else if let distance = hotel.distanceMiles {
                            Label("\(Int(distance)) mi", systemImage: "mappin.circle.fill")
                                .labelStyle(.titleAndIcon)
                        }
                        if let vibe = hotel.primaryVibe {
                            Text("·")
                            Label(vibe, systemImage: "sparkles")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .font(Theme.Typography.footnote)
                    .foregroundStyle(Theme.Color.textSecondary)
                }
                Spacer()
                if let rating = hotel.rating {
                    VStack(alignment: .trailing, spacing: 2) {
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                            .labelStyle(.titleAndIcon)
                            .font(Theme.Typography.bodyEmphasised)
                            .foregroundStyle(Theme.Color.textPrimary)
                        Text("(\(hotel.reviewCount))")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                }
            }

            HStack {
                if let productName = hotel.productName {
                    Text(productName)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                Spacer()
                if let price = hotel.cheapestPrice {
                    Text(formattedPrice(price, currency: currency))
                        .font(Theme.Typography.titleS)
                        .foregroundStyle(Theme.Color.accent)
                }
            }
            .padding(.top, Theme.Spacing.xs)
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.l))
        .shadow(
            color: Theme.Elevation.card.color,
            radius: Theme.Elevation.card.radius,
            x: Theme.Elevation.card.x,
            y: Theme.Elevation.card.y
        )
    }

    func formattedPrice(_ price: Double, currency: Currency) -> String {
        "\(currency.symbol)\(Int(price))"
    }

    var emptyState: some View {
        ContentUnavailableView {
            Label("No hotels available", systemImage: "house.slash")
        } description: {
            Text("We couldn't find any day passes near \(viewModel.state.location.name).")
        } actions: {
            Button("Back to Search") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Color.accent)
        }
    }

    func failedState(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't load hotels", systemImage: "exclamationmark.triangle")
                .foregroundStyle(Theme.Color.danger)
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") { viewModel.send(.retryTapped) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Color.accent)
        }
    }
}

// MARK: - Accessibility
