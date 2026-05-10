// HotelDetailScene.swift
// Architect-scaffolded surface for Transition 2 (matched-geometry expansion) and
// Transition 3 (swipe-down dismiss). Renders the hero + content visually but
// carries NO animation or gesture logic — Workers B and C fill those in.
//
// Contract (do not change without coordinating via SendMessage):
//   hotel:           the model the detail represents
//   currency:        for price formatting in the body
//   ns:              the host's matched-geometry namespace
//   sourceID:        matched-geometry id of the carousel card that was tapped
//                    — Worker B applies this to the hero's matchedGeometryEffect
//                    so the card morphs into the hero on expansion.
//   dismissProgress: 0 when fully expanded, 1 when dismiss-throw completes.
//                    Worker C is the writer (drag); the host is the reader (drives
//                    the explore layer's un-blur live as detail clears).
//   onDismiss:       called by Worker C once the dismiss commit threshold is hit.

import SwiftUI

struct HotelDetailScene: View {
    let hotel: Hotel
    let currency: Currency
    let ns: Namespace.ID
    let sourceID: String
    @Binding var dismissProgress: CGFloat
    var onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Theme.Color.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    hero
                    content
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollIndicators(.hidden)

            // Close affordance — temporary chevron until Worker C wires the
            // gesture-driven dismiss. Stays useful as a fallback for users who
            // can't perform a swipe.
            closeButton
        }
    }
}

// MARK: - Hero

private extension HotelDetailScene {
    /// Hero region — Worker B wires `matchedGeometryEffect(id: sourceID, in: ns)`
    /// onto this so the carousel card morphs into the full-bleed image.
    /// Worker C wires the `DragGesture` here for the swipe-down dismiss
    /// (gesture must NOT be on the whole scene — would eat ScrollView pan).
    var hero: some View {
        HotelImageCarousel(
            urls: hotel.imageURLs,
            hotelName: hotel.name,
            hotelStar: hotel.hotelStar
        )
        .frame(height: 360)
    }
}

// MARK: - Body content

private extension HotelDetailScene {
    @ViewBuilder
    var content: some View {
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
        .padding(.horizontal, Theme.Spacing.l)

        Divider()
            .padding(.horizontal, Theme.Spacing.l)

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
            .padding(.horizontal, Theme.Spacing.l)
        }
    }

    var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "chevron.down")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Color.textPrimary)
                .padding(Theme.Spacing.s + 2)
                .background(.ultraThinMaterial, in: Circle())
        }
        .padding(.leading, Theme.Spacing.m)
        .padding(.top, Theme.Spacing.m)
        .accessibilityLabel(Text("Close"))
    }
}

// MARK: - Preview

#Preview("HotelDetailScene") {
    HotelDetailScenePreviewWrapper()
}

private struct HotelDetailScenePreviewWrapper: View {
    @Namespace var ns
    @State var dismissProgress: CGFloat = 0

    var body: some View {
        HotelDetailScene(
            hotel: Hotel(
                id: 1,
                name: "Pendry Newport Beach",
                imageURL: URL(string: "https://images.unsplash.com/photo-1582719508461-905c673771fd?w=1200&q=80"),
                imageURLs: [],
                rating: 4.7,
                reviewCount: 128,
                hotelStar: 5,
                distanceMiles: 0.4,
                distanceText: "0.4 mi",
                cityName: "Newport Beach",
                stateCode: "CA",
                productName: "Pool Day Pass",
                primaryVibe: "coastal",
                cheapestPrice: 95
            ),
            currency: .usd,
            ns: ns,
            sourceID: "preview-source",
            dismissProgress: $dismissProgress,
            onDismiss: {}
        )
    }
}
