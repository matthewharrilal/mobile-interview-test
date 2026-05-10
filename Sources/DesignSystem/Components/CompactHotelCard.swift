// CompactHotelCard.swift
// Smaller hotel card sized for horizontal carousels inside sections.
// Image-bleed editorial layout — image dominates the card top, text floats
// below on the page (no card chrome around the photo). Width fits ~1.7 cards
// per screen for the peek-edge feel.

import SwiftUI

struct CompactHotelCard: View {
    let hotel: Hotel
    let currency: Currency
    var onTap: (() -> Void)?

    // Dynamic Type responsive frame — at default (.large) sizes match the
    // historical 220×200 layout exactly; at xxLarge+ the frame grows so the
    // hotel name and italic tagline have headroom and don't truncate/wrap.
    @ScaledMetric(relativeTo: .body) private var cardWidth: CGFloat = 220
    @ScaledMetric(relativeTo: .body) private var cardImageHeight: CGFloat = 200

    var body: some View {
        Button { onTap?() } label: {
            content
        }
        .buttonStyle(.cardPress)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HotelImageCarousel(
                urls: hotel.imageURLs,
                hotelName: hotel.name,
                hotelStar: hotel.hotelStar
            )
            .frame(width: cardWidth, height: cardImageHeight)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.l))
            .shadow(
                color: Theme.Elevation.cardCast.color.opacity(0.6),
                radius: Theme.Elevation.cardCast.radius * 0.6,
                x: 0,
                y: 4
            )

            VStack(alignment: .leading, spacing: 8) {
                // Eyebrow — tracked uppercase location
                if let location = hotel.displayLocation {
                    Text(location.uppercased())
                        // Semantic .caption2 (11pt baseline) so eyebrows
                        // scale with Dynamic Type at xxxLarge/AX sizes
                        // instead of staying frozen at 10pt.
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
                // Editorial sentence — italic serif. Reserve 2 lines so cards
                // with shorter taglines don't shrink and break the row's vertical rhythm.
                Text(hotel.editorialTagline)
                    .font(.system(.subheadline, design: .serif).italic())
                    .foregroundStyle(Theme.Color.textPrimary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Product/timeslot — the most relevant product info per the
                // interview spec. Surfaces the API's `product_name` (e.g.
                // "Pool Pass 9pm–10:45pm") in a tertiary role so the
                // editorial tagline keeps the visual lead while the
                // bookable surface is still legible at a glance.
                // `reservesSpace` keeps cards equal-height even when a
                // row lacks a product name.
                if let productName = hotel.productName, !productName.isEmpty {
                    Text(productName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.Color.textTertiary)
                        .lineLimit(1, reservesSpace: true)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Empty placeholder maintains card height parity with
                    // siblings that DO have a productName.
                    Color.clear.frame(height: 14)
                }

                // Tertiary price + stars — quiet, supporting role
                HStack(alignment: .center, spacing: Theme.Spacing.s) {
                    if let rating = hotel.rating, rating > 0 {
                        HStack(spacing: 3) {
                            StarRating(value: rating, size: 9)
                            Text(String(format: "%.1f", rating))
                                .font(.system(.caption, design: .serif).monospacedDigit())
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                    }
                    Spacer()
                    if let price = hotel.cheapestPrice {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("from")
                                .font(.system(.caption2, design: .serif).italic())
                                .foregroundStyle(Theme.Color.textTertiary)
                            Text("\(currency.symbol)\(Int(price))")
                                .font(.system(.subheadline, design: .serif).weight(.semibold).monospacedDigit())
                                .foregroundStyle(Theme.Color.textPrimary)
                                // Sweep iOS17 #3 — digits roll-and-flip
                                // when the price changes (currency
                                // toggle, refreshed listings) instead
                                // of crossfading. iOS 17+ API; matches
                                // the detail-scene price treatment so
                                // the morph reads as a single coherent
                                // transition rather than a card-fade-
                                // then-detail-fade sequence.
                                .contentTransition(.numericText())
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: cardWidth, alignment: .top)   // Width scales with Dynamic Type; height driven by .lineLimit(reservesSpace) so all cards align.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Strings.Accessibility.hotelRowLabel(
            name: hotel.name,
            rating: hotel.rating,
            distance: hotel.distanceText,
            price: hotel.cheapestPrice.map { "\(currency.symbol)\(Int($0))" }
        ))
    }
}
