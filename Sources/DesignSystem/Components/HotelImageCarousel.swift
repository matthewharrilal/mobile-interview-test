// HotelImageCarousel.swift
// Swipeable image carousel for a hotel card with a bottom gradient overlay
// that hosts the hotel name + star classification at editorial scale.
// Falls back to a branded placeholder when the URL list is empty.

import SwiftUI
import Kingfisher

struct HotelImageCarousel: View {
    let urls: [URL]
    let hotelName: String
    let hotelStar: Int?

    @State private var currentIndex = 0

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            imageContent
            gradientOverlay
            captionOverlay
            if urls.count > 1 {
                pagingIndicator
                    .padding(Theme.Spacing.s)
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .clipped()                                                   // chop image bleed before applying corner radius
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.l))
        .contentShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.l))
        .accessibilityElement()
        .accessibilityLabel(Text(hotelName))
        .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private var imageContent: some View {
        if urls.isEmpty {
            BrandedImagePlaceholder()
        } else {
            TabView(selection: $currentIndex) {
                ForEach(Array(urls.prefix(5).enumerated()), id: \.offset) { index, url in
                    KFImage(url)
                        .setProcessor(EditorialGradeProcessor())
                        .placeholder {
                            BrandedImagePlaceholder()
                        }
                        .fade(duration: Theme.Animation.kfFadeDuration)
                        .cancelOnDisappear(true)
                        .resizable()
                        .scaledToFill()
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    private var gradientOverlay: some View {
        LinearGradient(
            colors: [Color.black.opacity(0.62), Color.black.opacity(0.0)],
            startPoint: .bottom,
            endPoint: .top
        )
        .frame(maxHeight: .infinity, alignment: .bottom)
        .frame(height: 140, alignment: .bottom)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }

    private var captionOverlay: some View {
        HStack(alignment: .bottom) {
            Text(hotelName)
                .font(Theme.Typography.editorialL)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: Theme.Spacing.s)
            if let stars = hotelStar, stars > 0 {
                hotelStarBadge(stars: stars)
            }
        }
        .padding(Theme.Spacing.m)
    }

    private func hotelStarBadge(stars: Int) -> some View {
        HStack(spacing: 2) {
            Text("\(stars)")
                .font(Theme.Typography.metadata)
            Image(systemName: Theme.Icon.star)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: Theme.Spacing.hairline))
    }

    private var pagingIndicator: some View {
        Text("\(currentIndex + 1) / \(min(urls.count, 5))")
            // Semantic .caption2 so the paging text scales at large
            // Dynamic Type sizes; .monospacedDigit() preserves the
            // single-digit width while the surrounding size scales.
            .font(.system(.caption2, design: .rounded).weight(.medium).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, 4)
            .background(.black.opacity(0.4), in: Capsule())
    }
}
