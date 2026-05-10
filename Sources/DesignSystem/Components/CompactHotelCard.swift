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
            .frame(width: 220, height: 200)
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
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
                // Editorial sentence — italic serif, single line in the
                // luxury-hospitality voice
                Text(hotel.editorialTagline)
                    .font(.system(.subheadline, design: .serif).italic())
                    .foregroundStyle(Theme.Color.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 220, height: 340, alignment: .top)   // Uniform card height — locks layout against neighbors with longer/shorter taglines.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Strings.Accessibility.hotelRowLabel(
            name: hotel.name,
            rating: hotel.rating,
            distance: hotel.distanceText,
            price: hotel.cheapestPrice.map { "\(currency.symbol)\(Int($0))" }
        ))
    }
}
