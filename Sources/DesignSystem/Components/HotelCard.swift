// HotelCard.swift
// Editorial hotel card — large hero image with bottom-gradient hotel name +
// star classification, refined serif typography, generous breathing room,
// price as elegant inline text (not a chip). Magazine over marketplace.

import SwiftUI

struct HotelCard: View {
    let hotel: Hotel
    let currency: Currency
    var onTap: (() -> Void)?

    var body: some View {
        Button { onTap?() } label: {
            content
        }
        .buttonStyle(.cardPress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Strings.Accessibility.hotelRowLabel(
            name: hotel.name,
            rating: hotel.rating,
            distance: hotel.distanceText ?? hotel.distanceMiles.map { "\(Int($0)) miles" },
            price: hotel.cheapestPrice.map { "\(currency.symbol)\(Int($0))" }
        ))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HotelImageCarousel(
                urls: hotel.imageURLs,
                hotelName: hotel.name,
                hotelStar: hotel.hotelStar
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                metadataRow
                if let product = hotel.productName, hotel.cheapestPrice != nil {
                    priceRow(product: product)
                }
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
        .shadow(
            color: Theme.Elevation.card.color,
            radius: Theme.Elevation.card.radius,
            x: Theme.Elevation.card.x,
            y: Theme.Elevation.card.y
        )
    }

    private var metadataRow: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if let location = hotel.displayLocation {
                Text(location)
                    .font(Theme.Typography.metadata)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            if hotel.displayLocation != nil, hotel.rating ?? 0 > 0 {
                Text("·")
                    .foregroundStyle(Theme.Color.textTertiary)
            }
            if let rating = hotel.rating, rating > 0 {
                HStack(spacing: 3) {
                    Image(systemName: Theme.Icon.star)
                        .font(.system(size: 11, weight: .semibold))
                    Text(String(format: "%.1f", rating))
                        .font(Theme.Typography.metadata.monospacedDigit())
                    if hotel.reviewCount > 0 {
                        Text("(\(hotel.reviewCount))")
                            .font(Theme.Typography.caption.monospacedDigit())
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                }
                .foregroundStyle(Theme.Color.textSecondary)
            }
            Spacer()
            if let vibe = hotel.primaryVibe {
                Text(vibe.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Theme.Color.accent)
                    .padding(.horizontal, Theme.Spacing.s)
                    .padding(.vertical, 3)
                    .background(Theme.Color.accent.opacity(0.10), in: Capsule())
            }
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.top, Theme.Spacing.xs)
    }

    private func priceRow(product: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(product)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Color.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let price = hotel.cheapestPrice {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("from")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Color.textTertiary)
                    Text("\(currency.symbol)\(Int(price))")
                        .font(Theme.Typography.priceDisplay.monospacedDigit())
                        .foregroundStyle(Theme.Color.textPrimary)
                    Spacer()
                    Image(systemName: Theme.Icon.chevronRight)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Color.textTertiary)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.s)
    }
}
