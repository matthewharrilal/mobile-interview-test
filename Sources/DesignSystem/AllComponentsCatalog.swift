// AllComponentsCatalog.swift
// Single discoverability surface for every reusable component in the
// design system. Lets a reviewer (or future engineer onboarding) see
// the full inventory at default + Dynamic Type sizes + light/dark
// without hunting through individual files.
//
// Lives next to the design-system tokens so the catalog is co-located
// with what it documents. Not shipped at runtime — `#Preview` macros
// compile to a no-op in Release.

import SwiftUI

#if DEBUG
struct AllComponentsCatalog: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                section("Star Rating") {
                    HStack(spacing: Theme.Spacing.m) {
                        StarRating(value: 5.0, size: 12)
                        StarRating(value: 4.5, size: 14)
                        StarRating(value: 3.0, size: 16)
                    }
                }

                section("Filter Chip Row") {
                    FilterChipRow(
                        filters: HotelListingsState.Filter.allCases,
                        selected: .constant(.all)
                    )
                }

                section("Compact Hotel Card") {
                    HStack(spacing: Theme.Spacing.m) {
                        ForEach(Hotel.previewFixtures) { hotel in
                            CompactHotelCard(hotel: hotel, currency: .usd)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.m)
                }

                section("Branded Image Placeholder") {
                    BrandedImagePlaceholder()
                        .frame(width: 200, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.l))
                }

                section("Theme Colors") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        swatch("background", Theme.Color.background)
                        swatch("surface", Theme.Color.surface)
                        swatch("surfaceRecessed", Theme.Color.surfaceRecessed)
                        swatch("textPrimary", Theme.Color.textPrimary)
                        swatch("textSecondary", Theme.Color.textSecondary)
                        swatch("textTertiary", Theme.Color.textTertiary)
                        swatch("border", Theme.Color.border)
                        swatch("accent", Theme.Color.accent)
                        swatch("danger", Theme.Color.danger)
                    }
                }

                section("Typography") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("Body — Theme.Typography.body").font(Theme.Typography.body)
                        Text("Editorial L — Theme.Typography.editorialL").font(Theme.Typography.editorialL)
                        Text("Editorial M — Theme.Typography.editorialM").font(Theme.Typography.editorialM)
                        Text("Editorial Display — Theme.Typography.editorialDisplay").font(Theme.Typography.editorialDisplay)
                        Text("Metadata — Theme.Typography.metadata").font(Theme.Typography.metadata)
                        Text("Price Display — Theme.Typography.priceDisplay").font(Theme.Typography.priceDisplay)
                    }
                }
            }
            .padding(Theme.Spacing.l)
        }
        .background(Theme.Color.background.ignoresSafeArea())
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.Color.textTertiary)
            content()
        }
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.s)
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay(RoundedRectangle(cornerRadius: Theme.CornerRadius.s).strokeBorder(Theme.Color.border))
            Text(name)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Color.textPrimary)
        }
    }
}

#Preview("All Components — Light") {
    AllComponentsCatalog()
}

#Preview("All Components — Dark") {
    AllComponentsCatalog()
        .preferredColorScheme(.dark)
}

#Preview("All Components — XXL Dynamic Type") {
    AllComponentsCatalog()
        .dynamicTypeSize(.xxLarge)
}

#Preview("All Components — AX5") {
    AllComponentsCatalog()
        .dynamicTypeSize(.accessibility5)
}
#endif
