// BrandedImagePlaceholder.swift
// Fallback rendered when an image URL is nil or fails to load.
// Replaces the generic gray rectangle with a branded gradient + symbol so the
// empty state still feels like part of the product.
//
// NOTE: this view is hosted inside `HotelImageCarousel`, which is the
// matched-geometry'd element during the card → detail morph (iOS 17) and
// the `.matchedTransitionSource` source view (iOS 18 zoom). So it must
// stay free of `.layerEffect` and other CoreAnimation-side effects that
// would contend for transition layer ownership. The skeleton-shimmer
// `.layerEffect(...)` lives on the standalone loading skeletons in
// HotelListingsView (see `SkeletonShimmer` below).

import SwiftUI

struct BrandedImagePlaceholder: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.Color.accent.opacity(0.18),
                    Theme.Color.accent.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.Color.accent.opacity(0.6))
        }
    }
}

// MARK: - .layerEffect bridge (cohesion-supplemental)

/// View modifier that applies the `skeletonShimmer` Metal stitchable
/// function from `EditorialShaders.metal` via SwiftUI's
/// `.layerEffect(...)`. Pumps a `time` argument from a `TimelineView`
/// so the shader animates at the display's native refresh rate without
/// `withAnimation` ceremony.
///
/// Apply ONLY to non-matched-geometry surfaces. Currently used on the
/// loading-skeleton blocks in `HotelListingsView` (`skeletonSection`),
/// which are shown briefly during initial fetch and never wear a
/// matched-transition source.
struct SkeletonShimmer: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                content.visualEffect { view, proxy in
                    view.layerEffect(
                        ShaderLibrary.default.skeletonShimmer(
                            .float2(proxy.size),
                            .float(Float(time.truncatingRemainder(dividingBy: 100)))
                        ),
                        maxSampleOffset: .zero
                    )
                }
            }
        } else {
            content
        }
    }
}

extension View {
    /// Cohesion-supplemental shimmer for loading skeletons. iOS 17+ runs
    /// a Metal stitchable function via `.layerEffect`; older OSes fall
    /// through to the unmodified content.
    func skeletonShimmer() -> some View { modifier(SkeletonShimmer()) }
}
