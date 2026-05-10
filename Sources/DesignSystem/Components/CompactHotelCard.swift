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
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.l))
            .shadow(
                color: Theme.Elevation.cardCast.color.opacity(0.6),
                radius: Theme.Elevation.cardCast.radius * 0.6,
                x: 0,
                y: 4
            )

            VStack(alignment: .leading, spacing: 6) {
                if let location = hotel.displayLocation {
                    Text(location.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
                if let rating = hotel.rating, rating > 0 {
                    HStack(spacing: 4) {
                        StarRating(value: rating, size: 10)
                        Text(String(format: "%.1f", rating))
                            .font(.system(.footnote, design: .serif).weight(.medium).monospacedDigit())
                            .foregroundStyle(Theme.Color.textPrimary)
                    }
                }
                if let price = hotel.cheapestPrice {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("from")
                            .font(.system(.caption2, design: .serif).italic())
                            .foregroundStyle(Theme.Color.textTertiary)
                        Text("\(currency.symbol)\(Int(price))")
                            .font(.system(.headline, design: .serif).weight(.semibold).monospacedDigit())
                            .foregroundStyle(Theme.Color.textPrimary)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(width: 220)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Strings.Accessibility.hotelRowLabel(
            name: hotel.name,
            rating: hotel.rating,
            distance: hotel.distanceText,
            price: hotel.cheapestPrice.map { "\(currency.symbol)\(Int($0))" }
        ))
    }
}
