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
    /// Invoked when the user commits the dismiss gesture. The CGFloat is
    /// the throw velocity along the drag axis in pt/sec, computed from the
    /// gesture's `predictedEndTranslation` over SwiftUI's ~0.1s prediction
    /// window. The host uses this to scale the morph spring's response so
    /// a fast flick dismisses faster than a slow drag — closes the velocity
    /// discontinuity at the gesture release boundary
    /// (cohesion-animation-system B-3 fix).
    var onDismiss: (CGFloat) -> Void

    /// 0 while the matched-geometry hero is still morphing from the card,
    /// 1 once the surrounding content has faded in. Driven by a `.task`
    /// that fires ~160ms after mount (geometry settles ~150ms; the brief
    /// asks for an 80–100ms beat AFTER that before content appears).
    @State private var contentOpacity: Double = 0

    /// Live drag translation on the hero. Drives `dismissProgress` (writer
    /// contract) and the rubber-band offset on the hero itself. Reset on
    /// snap-back; on commit the host's morph-spring drives unwind.
    @State private var dragTranslation: CGFloat = 0

    // MARK: Drag thresholds (per UX-research §7)
    /// Below this point, release rubber-bands back — no commit.
    private static let dismissCancelBelow: CGFloat = 100
    /// At/above this point, release commits the dismiss.
    private static let dismissCommitAt: CGFloat = 200
    /// `dismissProgress` reaches 1.0 when translation hits this value.
    private static let dismissProgressDistance: CGFloat = 600

    var body: some View {
        // Cap opacity at 0.999 to stay within the layer-promoted regime —
        // crossing exactly 1.0 makes SwiftUI un-promote the layer on the
        // final frame, producing a visible "snap" on every morph settle
        // (cohesion-rendering-pipeline F-1 fix).
        let safeOpacity = min(contentOpacity, 0.999)
        return ZStack(alignment: .topLeading) {
            // Detail surface — fades in BEHIND the morphing hero so the
            // hero stays continuously visible while the surface arrives.
            Theme.Color.background
                .ignoresSafeArea()
                .opacity(safeOpacity)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    hero
                    content
                        .opacity(safeOpacity)
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)

            // Close affordance — temporary chevron until Worker C wires the
            // gesture-driven dismiss. Stays useful as a fallback for users who
            // can't perform a swipe.
            closeButton
                .opacity(safeOpacity)
        }
        .onAppear {
            // Geometry settles ~150ms (spring response 0.25, damping 0.95);
            // brief asks for 80–100ms beat before content fade-in. Driving
            // the reveal off `.onAppear` with an animation `.delay` keeps
            // the timing identical to the prior `Task.sleep(160ms)` while
            // removing the interruption race (Phase A surgical fix —
            // structural state-bound coordination is Phase B).
            withAnimation(Theme.Animation.contentReveal.delay(0.16)) {
                contentOpacity = 1
            }
        }
    }
}

// MARK: - Hero

private extension HotelDetailScene {
    /// Hero region — wears the same matched-geometry id as the carousel card,
    /// so SwiftUI morphs the card into the hero (and back) on presentation
    /// changes. The lift shadow during the morph reads as a "card stepping
    /// off the page" — Airbnb uses an equivalent cue at frame 4–5 of their
    /// expansion. The card (carousel) is the source; this destination omits
    /// `isSource:` so the pair has exactly one source — avoids undefined
    /// dual-source behavior.
    ///
    /// Sibling-layer shadow pattern (cohesion-rendering-pipeline F + H fix):
    /// the radius-24 shadow is hosted by an INVISIBLE carrier RoundedRectangle
    /// in a sibling layer rather than as a `.shadow(...)` modifier on the
    /// morphing hero itself. That isolates the shadow's promoted backing
    /// store from the morphing frame so the Gaussian blur target is not
    /// re-rasterized on every frame as the hero grows ~4× across 250 ms.
    /// The carrier shares the hero's matched-geometry id with the
    /// ".shadow" suffix to keep its frame in sync without a corresponding
    /// source on the card (the source-card carries no shadow at this id;
    /// the carrier fades in via `contentOpacity` so it doesn't ghost-jump).
    ///
    /// Worker C wires the `DragGesture` here for the swipe-down dismiss
    /// (gesture must NOT be on the whole scene — would eat ScrollView pan).
    var hero: some View {
        ZStack {
            // Shadow sibling — stable layer-promoted backing store, frame
            // synced via matched-geometry id derived from sourceID. Uses
            // a near-zero opacity carrier so the shadow has a substrate
            // to render against without painting any visible fill.
            RoundedRectangle(cornerRadius: Theme.CornerRadius.l)
                .fill(Color.black.opacity(0.001))
                .frame(height: 360)
                .matchedGeometryEffect(id: "\(sourceID).shadow", in: ns)
                .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
                .opacity(min(contentOpacity, 0.999))

            // Hero image — no shadow; pure matched-geometry frame morph.
            HotelImageCarousel(
                urls: hotel.imageURLs,
                hotelName: hotel.name,
                hotelStar: hotel.hotelStar
            )
            .frame(height: 360)
            .matchedGeometryEffect(id: sourceID, in: ns)
        }
        .offset(y: rubberBandedOffset(for: dragTranslation))
        .gesture(dismissDrag)
    }

    /// Light rubber-band so even sub-100pt drags feel tactile. Linear up to
    /// 100pt, then sqrt-damped past that — keeps the hero visible without
    /// running off the screen during a committed throw.
    func rubberBandedOffset(for translation: CGFloat) -> CGFloat {
        guard translation > 0 else { return 0 }
        if translation <= Self.dismissCancelBelow { return translation }
        let excess = translation - Self.dismissCancelBelow
        return Self.dismissCancelBelow + sqrt(excess * 40)
    }

    /// Drag gesture on the hero that drives the `dismissProgress` binding
    /// (writer contract) and fires `onDismiss` once the commit threshold
    /// is crossed on release. Restricted to the hero so ScrollView panning
    /// of the content below remains unaffected.
    var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let downward = max(0, value.translation.height)
                dragTranslation = downward
                dismissProgress = min(1, max(0, downward / Self.dismissProgressDistance))
            }
            .onEnded { value in
                let downward = max(0, value.translation.height)
                if downward >= Self.dismissCommitAt {
                    // Pass throw velocity (pt/sec along drag axis) to the host
                    // so it can scale the morph-spring envelope proportionally
                    // — eliminates the visible "stick" at gesture release that
                    // happens when the dismiss spring starts from rest.
                    // SwiftUI's predictedEndTranslation projects ~0.1s ahead;
                    // (predicted - actual) / 0.1 ≈ instantaneous velocity.
                    let predicted = max(0, value.predictedEndTranslation.height)
                    let throwVelocity = max(0, (predicted - downward) / 0.1)
                    // Host owns the morph-spring envelope on `onDismiss`;
                    // we just fire the callback with the velocity and let it run.
                    onDismiss(throwVelocity)
                } else {
                    // Rubber-band snap-back — both <100pt and 100–200pt
                    // bands cancel. Spring back to rest.
                    withAnimation(Theme.Animation.snapBack) {
                        dragTranslation = 0
                        dismissProgress = 0
                    }
                }
            }
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
        // Tap-driven dismiss carries no throw velocity — host receives 0
        // and uses its baseline morph-spring envelope.
        Button(action: { onDismiss(0) }) {
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
            onDismiss: { _ in }
        )
    }
}
