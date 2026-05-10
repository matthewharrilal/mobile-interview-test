// HotelCard.swift
// Editorial hotel card with layered depth: dual-shadow elevation, warm-white
// gradient surface, floating price pill that overlaps the image edge, real
// star rating, gradient vibe chip, italic typographic flourishes.
// Magazine over marketplace — character through layered materials.

import SwiftUI

struct HotelCard: View {
    let hotel: Hotel
    let currency: Currency
    var onTap: (() -> Void)?

    var body: some View {
        Button { onTap?() } label: {
            cardBody
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

    private var cardBody: some View {
        VStack(spacing: 0) {
            // Hero image with name overlay + classification badge
            HotelImageCarousel(
                urls: hotel.imageURLs,
                hotelName: hotel.name,
                hotelStar: hotel.hotelStar
            )
            .overlay(
                // Subtle 1px inner ring on the image for definition
                RoundedRectangle(cornerRadius: Theme.CornerRadius.l)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            )

            // Body — warm gradient surface with layered content
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                metadataRow
                Divider()
                    .background(Theme.Color.border)
                productAndPriceRow
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.top, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.m + 2)
            .background(surfaceGradient)
            .clipShape(
                .rect(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: Theme.CornerRadius.l,
                    bottomTrailingRadius: Theme.CornerRadius.l,
                    topTrailingRadius: 0
                )
            )
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.l)
                .fill(Theme.Color.surface)
        )
        .overlay(alignment: .top) {
            // Top inner highlight — gives a "lifted" glassy edge
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.25), Color.white.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(height: 1)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.l))
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.l))
        // Layered shadows: tight ambient + wide cast for true Z-depth
        .shadow(
            color: Theme.Elevation.cardAmbient.color,
            radius: Theme.Elevation.cardAmbient.radius,
            x: Theme.Elevation.cardAmbient.x,
            y: Theme.Elevation.cardAmbient.y
        )
        .shadow(
            color: Theme.Elevation.cardCast.color,
            radius: Theme.Elevation.cardCast.radius,
            x: Theme.Elevation.cardCast.x,
            y: Theme.Elevation.cardCast.y
        )
    }

    // MARK: - Surface gradient

    /// Warm-white → cool-white. Adds chromatic depth instead of flat #FFFFFF.
    private var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.998, blue: 0.992),     // warm cream top
                Color(red: 0.985, green: 0.985, blue: 0.99)     // cooler off-white bottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Metadata row (location · stars · vibe)

    private var metadataRow: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.s) {
            VStack(alignment: .leading, spacing: 4) {
                if let location = hotel.displayLocation {
                    Text(location.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
                if let rating = hotel.rating, rating > 0 {
                    HStack(alignment: .center, spacing: Theme.Spacing.xs) {
                        StarRating(value: rating, size: 11)
                        Text(String(format: "%.1f", rating))
                            .font(.system(.subheadline, design: .serif).weight(.medium).monospacedDigit())
                            .foregroundStyle(Theme.Color.textPrimary)
                        if hotel.reviewCount > 0 {
                            Text("(\(hotel.reviewCount))")
                                .font(.system(.caption).monospacedDigit())
                                .foregroundStyle(Theme.Color.textTertiary)
                        }
                    }
                }
            }
            Spacer(minLength: Theme.Spacing.s)
            if let vibe = hotel.primaryVibe {
                vibeChip(text: vibe)
            }
        }
    }

    /// Gradient vibe chip — deeper presence than flat opacity.
    private func vibeChip(text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .tracking(1.1)
            .foregroundStyle(Theme.Color.accent)
            .padding(.horizontal, Theme.Spacing.s + 2)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(LinearGradient(
                    colors: [
                        Theme.Color.accent.opacity(0.16),
                        Theme.Color.accent.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            )
            .overlay(
                Capsule().stroke(Theme.Color.accent.opacity(0.25), lineWidth: 0.5)
            )
    }

    // MARK: - Product + price row (with floating chevron chip)

    @ViewBuilder
    private var productAndPriceRow: some View {
        if let product = hotel.productName {
            HStack(alignment: .center, spacing: Theme.Spacing.m) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(product)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let price = hotel.cheapestPrice {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("from")
                                .font(.system(.caption, design: .serif).italic())
                                .foregroundStyle(Theme.Color.textTertiary)
                            Text("\(currency.symbol)\(Int(price))")
                                .font(Theme.Typography.priceDisplay.monospacedDigit())
                                .foregroundStyle(Theme.Color.textPrimary)
                        }
                    }
                }
                Spacer(minLength: Theme.Spacing.s)
                chevronChip
            }
        }
    }

    /// Floating chevron in a circle — matches the back-button language for
    /// visual rhythm + signals tappability.
    private var chevronChip: some View {
        Image(systemName: Theme.Icon.chevronRight)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.Color.textSecondary)
            .frame(width: 32, height: 32)
            .background(
                Circle().fill(LinearGradient(
                    colors: [
                        Theme.Color.surface,
                        Theme.Color.surfaceRecessed
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            )
            .overlay(Circle().stroke(Theme.Color.border, lineWidth: 0.5))
            .shadow(
                color: Theme.Elevation.floatingChip.color,
                radius: Theme.Elevation.floatingChip.radius,
                x: Theme.Elevation.floatingChip.x,
                y: Theme.Elevation.floatingChip.y
            )
    }
}
