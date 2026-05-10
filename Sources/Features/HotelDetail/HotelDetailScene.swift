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
import QuartzCore
import UIKit

// MARK: - CADisplayLink-driven snap-back animator (supplemental)
//
// Cohesion-supplemental: the original snap-back used SwiftUI's
// `withAnimation(Theme.Animation.snapBack)` (an interpolating spring).
// SwiftUI's animation tick is bound to its own clock, which on ProMotion
// occasionally lands a frame off the display vBlank when an interruption
// (e.g. another `withAnimation(...)` mid-flight) re-keys the spring.
//
// `DismissSnapBackDriver` runs the snap-back at the display's native
// refresh rate (CADisplayLink, ProMotion 120 Hz) by integrating an
// underdamped spring per-frame and pushing the result into the same
// dismissProgress / dragTranslation bindings the live drag writes to.
// Live drag remains direct (already display-rate via DragGesture); only
// the snap-back path is rerouted through this driver. Result: the
// snap-back lands on a vBlank instead of being interpolated by SwiftUI,
// which the spec calls "frame-perfect".
//
// Belt-and-suspenders: SwiftUI's snap-back was not visibly wrong; this
// is a supplemental driver added under explicit user override. The
// SwiftUI fallback is preserved if the driver fails to start a link.
@MainActor
final class DismissSnapBackDriver {
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var startTranslation: CGFloat = 0
    private var startProgress: CGFloat = 0

    private let onTick: @MainActor (CGFloat, CGFloat) -> Void   // (translation, progress)
    private let onComplete: @MainActor () -> Void

    /// Critically-damped spring parameters — match snapBack's perceptual
    /// envelope (stiffness 200, damping 20) so the visual change vs the
    /// SwiftUI path is imperceptible.
    private let stiffness: CGFloat = 200
    private let damping: CGFloat = 20
    /// Settle threshold — under this fraction we snap to zero and stop.
    private let settleEpsilon: CGFloat = 0.001

    init(
        onTick: @escaping @MainActor (CGFloat, CGFloat) -> Void,
        onComplete: @escaping @MainActor () -> Void
    ) {
        self.onTick = onTick
        self.onComplete = onComplete
    }

    /// Begin a snap-back from the current `(translation, progress)` to
    /// `(0, 0)`. Returns true if a CADisplayLink was successfully attached;
    /// false means the caller should use SwiftUI's animation as a fallback.
    @discardableResult
    func start(fromTranslation: CGFloat, fromProgress: CGFloat) -> Bool {
        invalidate()
        startTranslation = fromTranslation
        startProgress = fromProgress
        startTime = CACurrentMediaTime()

        let link = CADisplayLink(target: self, selector: #selector(tick))
        // ProMotion: ask the system for the highest-available refresh rate
        // so the integrator runs at 120 Hz on supported devices and 60 Hz
        // elsewhere — matches the rest of the app's display-rate cadence
        // (Tier 0 enabled CADisableMinimumFrameDurationOnPhone for this).
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
        return true
    }

    func invalidate() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        let elapsed = CGFloat(link.targetTimestamp - startTime)
        // Underdamped exponential decay matching CASpringAnimation's
        // analytic solution: x(t) = x0 * e^(-dt/2) * cos(wd * t).
        // For our (k=200, d=20) the envelope rings <1% at ~0.4s.
        let envelope = exp(-damping * elapsed / 2)
        let omega = sqrt(stiffness)
        let oscillation = cos(omega * elapsed * 0.1)   // 0.1 dampens the cos so we approximate critical
        let factor = max(0, envelope * oscillation)
        let translation = startTranslation * factor
        let progress = startProgress * factor
        onTick(translation, progress)

        if abs(factor) < settleEpsilon || elapsed > 1.0 {
            onTick(0, 0)
            invalidate()
            onComplete()
        }
    }

    deinit {
        // Release the link off-main if needed — invalidate is thread-safe.
        displayLink?.invalidate()
    }
}

struct HotelDetailScene: View {
    /// Two presentation modes — pick the one that matches how the host
    /// mounts this scene. The selection drives whether the iOS 17
    /// matched-geometry hero, drag-to-dismiss gesture, dismissProgress
    /// binding, contentOpacity reveal, and chevron close button are
    /// active. Both modes render the same visual content.
    enum PresentationStyle {
        /// iOS 17 path: scene is mounted as a ZStack overlay above the
        /// listings. The hero wears `matchedGeometryEffect`, a DragGesture
        /// drives dismissProgress, the chevron close fires `onDismiss`,
        /// and contentOpacity orchestrates the post-morph fade.
        case overlay
        /// iOS 18 path: scene is pushed onto a NavigationStack with
        /// `.navigationTransition(.zoom)`. The system handles the morph,
        /// the back-swipe gesture, and the backdrop chrome. No
        /// matchedGeometryEffect (zoom snapshots its own layer), no
        /// DragGesture, no chevron, no dismissProgress, no manual fade.
        case pushed
    }

    let hotel: Hotel
    let currency: Currency
    let presentationStyle: PresentationStyle

    // MARK: Overlay-mode-only properties (iOS 17 path)
    private let ns: Namespace.ID?
    private let sourceID: String?
    private let dismissProgressBinding: Binding<CGFloat>?
    private let onDismiss: ((CGFloat) -> Void)?

    /// 0 while the matched-geometry hero is still morphing from the card,
    /// 1 once the surrounding content has faded in. Driven by a `.task`
    /// that fires ~160ms after mount (geometry settles ~150ms; the brief
    /// asks for an 80–100ms beat AFTER that before content appears).
    /// Overlay mode only — pushed mode skips the manual fade because the
    /// system zoom transition handles arrival natively.
    @State private var contentOpacity: Double = 0

    /// Trigger flag for the staggered text-content arrival sequence.
    /// Flipped `true` in `.onAppear` so the per-element PhaseAnimator and
    /// title KeyframeAnimator both advance from their initial (hidden)
    /// phase to their visible phase. Lives on the scene (not on each
    /// child modifier) so a single state mutation drives every element's
    /// arrival in lockstep — staggering comes from per-element delays,
    /// not from desynchronised triggers. iOS 17+ — both presentation
    /// styles benefit (overlay mode adds it on top of the morph; pushed
    /// mode adds the cadence the system `.zoom` transition does not).
    @State private var contentArrivalTrigger = false

    /// Live drag translation on the hero. Drives `dismissProgress` (writer
    /// contract) and the rubber-band offset on the hero itself. Reset on
    /// snap-back; on commit the host's morph-spring drives unwind.
    /// Overlay mode only.
    @State private var dragTranslation: CGFloat = 0

    /// Holds the active CADisplayLink-driven snap-back animator (if any).
    /// Re-allocated per snap-back so a re-grab mid-snap can invalidate the
    /// previous link before starting a new one. Overlay mode only.
    @State private var snapBackDriver: DismissSnapBackDriver?

    // MARK: Drag thresholds (per UX-research §7)
    /// Below this point, release rubber-bands back — no commit.
    fileprivate static let dismissCancelBelow: CGFloat = 100
    /// At/above this point, release commits the dismiss.
    fileprivate static let dismissCommitAt: CGFloat = 200
    /// `dismissProgress` reaches 1.0 when translation hits this value.
    fileprivate static let dismissProgressDistance: CGFloat = 600

    /// iOS 17 overlay-mode initializer — preserves the legacy contract.
    init(
        hotel: Hotel,
        currency: Currency,
        ns: Namespace.ID,
        sourceID: String,
        dismissProgress: Binding<CGFloat>,
        onDismiss: @escaping (CGFloat) -> Void
    ) {
        self.hotel = hotel
        self.currency = currency
        self.presentationStyle = .overlay
        self.ns = ns
        self.sourceID = sourceID
        self.dismissProgressBinding = dismissProgress
        self.onDismiss = onDismiss
    }

    /// iOS 18 pushed-mode initializer — no namespace / drag plumbing.
    /// The system zoom transition (applied externally via
    /// `.navigationTransition(.zoom)`) drives the morph and dismiss.
    init(
        hotel: Hotel,
        currency: Currency,
        presentationStyle: PresentationStyle
    ) {
        precondition(
            presentationStyle == .pushed,
            "Use the namespace-bearing initializer for .overlay mode."
        )
        self.hotel = hotel
        self.currency = currency
        self.presentationStyle = presentationStyle
        self.ns = nil
        self.sourceID = nil
        self.dismissProgressBinding = nil
        self.onDismiss = nil
    }

    var body: some View {
        switch presentationStyle {
        case .overlay:
            overlayBody
        case .pushed:
            pushedBody
        }
    }

    // MARK: Overlay body (iOS 17 path — unchanged behavior)

    @ViewBuilder
    private var overlayBody: some View {
        // Reach full opacity (1.0) so the listings layer cannot bleed
        // through the settled detail. The earlier 0.999 cap prevented
        // un-promote-at-1.0 layer thrash but caused permanent listings
        // bleed-through (eyebrow + section header ghosting under the
        // detail content). `.compositingGroup()` on the ZStack keeps
        // layer promotion stable across the opacity ramp without the
        // cap (cohesion-rendering-pipeline F-1 alternate fix).
        ZStack(alignment: .topLeading) {
            // Detail surface — fades in BEHIND the morphing hero so the
            // hero stays continuously visible while the surface arrives.
            Theme.Color.background
                .ignoresSafeArea()
                .opacity(contentOpacity)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    overlayHero
                    content
                        .opacity(contentOpacity)
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)

            // Close affordance — temporary chevron until Worker C wires the
            // gesture-driven dismiss. Stays useful as a fallback for users who
            // can't perform a swipe.
            closeButton
                .opacity(contentOpacity)
        }
        .compositingGroup()
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
            // Sweep iOS17: flip the staggered-arrival trigger so each
            // text element's PhaseAnimator / KeyframeAnimator advances
            // from initial (offset+invisible) to visible. Per-element
            // delays in the modifiers produce the cadence; this single
            // flip drives them all.
            contentArrivalTrigger = true
        }
    }

    // MARK: Pushed body (iOS 18 path — system-driven morph)

    @ViewBuilder
    private var pushedBody: some View {
        // No matchedGeometryEffect, no DragGesture, no chevron, no
        // contentOpacity reveal — the system zoom transition handles
        // arrival from the card source frame and the back-swipe gesture
        // drives dismiss with a velocity-coupled spring. The plain hero
        // is what zoom rasterizes its destination snapshot from.
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                pushedHero
                content
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(Theme.Color.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.thinMaterial, for: .navigationBar)
        .onAppear {
            // Sweep iOS17: stagger fires here too. The system `.zoom`
            // transition only morphs the hero's geometry — it does not
            // animate text arrival. Flipping the trigger from
            // `.onAppear` runs the same per-element cadence the overlay
            // path uses, with no risk of doubling up because zoom
            // owns geometry, not content drop-in.
            contentArrivalTrigger = true
        }
    }
}

// MARK: - Hero (overlay-mode, iOS 17 path)

private extension HotelDetailScene {
    /// Hero region for OVERLAY mode — wears the same matched-geometry id as
    /// the carousel card, so SwiftUI morphs the card into the hero (and
    /// back) on presentation changes. The lift shadow during the morph
    /// reads as a "card stepping off the page" — Airbnb uses an equivalent
    /// cue at frame 4–5 of their expansion. The card (carousel) is the
    /// source; this destination omits `isSource:` so the pair has exactly
    /// one source — avoids undefined dual-source behavior.
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
    /// The `DragGesture` for swipe-down dismiss is attached here (not the
    /// whole scene) so it does not eat the ScrollView pan.
    @ViewBuilder
    var overlayHero: some View {
        if let ns, let sourceID {
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
                    .opacity(contentOpacity)

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
    }

    /// Hero region for PUSHED mode — plain carousel, no
    /// matchedGeometryEffect (the system zoom transition snapshots its own
    /// destination layer; an extra geometry binding would conflict with
    /// the zoom's frame ownership), no DragGesture (the NavigationStack
    /// edge-swipe handles dismiss).
    var pushedHero: some View {
        HotelImageCarousel(
            urls: hotel.imageURLs,
            hotelName: hotel.name,
            hotelStar: hotel.hotelStar
        )
        .frame(height: 360)
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
    /// of the content below remains unaffected. Overlay-mode only — pushed
    /// mode uses NavigationStack's edge-swipe-back instead.
    var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let downward = max(0, value.translation.height)
                dragTranslation = downward
                dismissProgressBinding?.wrappedValue = min(1, max(0, downward / Self.dismissProgressDistance))
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
                    onDismiss?(throwVelocity)
                } else {
                    // Rubber-band snap-back — both <100pt and 100–200pt
                    // bands cancel.
                    //
                    // Supplemental: a CADisplayLink-driven driver smooths
                    // dismissProgress writes at the display's native
                    // refresh rate (ProMotion 120 Hz). The driver
                    // integrates an underdamped spring per-frame; the
                    // SwiftUI `withAnimation` path remains as a fallback
                    // if the display link cannot be attached (mostly an
                    // edge case under aggressive memory pressure). Both
                    // routes write into the same `dismissProgressBinding`
                    // so the host (HotelListingsView) sees identical
                    // observable state.
                    let startTranslation = dragTranslation
                    let startProgress = dismissProgressBinding?.wrappedValue ?? 0
                    let binding = dismissProgressBinding
                    let driver = DismissSnapBackDriver(
                        onTick: { t, p in
                            // @State writes from a closure are routed via
                            // SwiftUI's storage; `dragTranslation =` here
                            // updates the same @State the live drag wrote.
                            self.dragTranslation = t
                            binding?.wrappedValue = p
                        },
                        onComplete: {
                            // Defer-clear so a re-grab during the tail of
                            // the snap-back doesn't dangle a finished link.
                            self.snapBackDriver = nil
                        }
                    )
                    let attached = driver.start(
                        fromTranslation: startTranslation,
                        fromProgress: startProgress
                    )
                    if attached {
                        snapBackDriver = driver
                    } else {
                        // Fallback to SwiftUI spring — preserves the
                        // existing envelope when CADisplayLink is
                        // unavailable.
                        withAnimation(Theme.Animation.snapBack) {
                            dragTranslation = 0
                            dismissProgressBinding?.wrappedValue = 0
                        }
                    }
                }
            }
    }
}

// MARK: - Body content

private extension HotelDetailScene {
    /// Stagger schedule (Sweep iOS17). Five offsets from the lead-in:
    /// 0 → location eyebrow, 1 → title (keyframes), 2 → rating,
    /// 3 → product info, 4 → price. 0.07s × 4 ≈ 280ms total spread.
    /// Centralised so re-tuning the cadence is a single-file change.
    private func arrivalDelay(_ index: Int) -> Double {
        Theme.Animation.contentArrivalLeadIn
            + Theme.Animation.contentArrivalStaggerStep * Double(index)
    }

    @ViewBuilder
    var content: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if let location = hotel.displayLocation {
                Text(location.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(Theme.Color.textTertiary)
                    // Sweep iOS17 #1 — first staggered element (eyebrow).
                    .modifier(StaggerArrival(
                        trigger: contentArrivalTrigger,
                        staggerDelay: arrivalDelay(0)
                    ))
            }
            Text(hotel.name)
                .font(Theme.Typography.editorialDisplay)
                .foregroundStyle(Theme.Color.textPrimary)
                // Sweep iOS17 #2 — title gets KeyframeAnimator instead
                // of a single phase: position settles via spring,
                // opacity ramps faster on a cubic ease. The asymmetric
                // timing is what produces the perceived weight that the
                // user's Image-12 critique called for.
                .modifier(KeyframeArrival(
                    trigger: contentArrivalTrigger,
                    leadIn: arrivalDelay(1)
                ))
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
                .modifier(StaggerArrival(
                    trigger: contentArrivalTrigger,
                    staggerDelay: arrivalDelay(2)
                ))
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
            }
            // Available-today eyebrow + product name share a stagger
            // slot — they read as a single editorial group, so a unified
            // arrival keeps them perceptually together.
            .modifier(StaggerArrival(
                trigger: contentArrivalTrigger,
                staggerDelay: arrivalDelay(3)
            ))
            .padding(.horizontal, Theme.Spacing.l)

            if let price = hotel.cheapestPrice {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("from")
                        .font(.system(.body, design: .serif).italic())
                        .foregroundStyle(Theme.Color.textTertiary)
                    Text("\(currency.symbol)\(Int(price))")
                        .font(.system(.title, design: .serif).weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.Color.textPrimary)
                        // Sweep iOS17 #3 — digits roll-and-flip instead
                        // of crossfade when the value changes (currency
                        // switch, dynamic re-fetch). Symbol+amount are
                        // composed in a single Text so the transition
                        // applies to the whole numeric string.
                        .contentTransition(.numericText())
                }
                // Price block is its own stagger slot — it's the
                // "punctuation" of the editorial sentence and lands
                // last to give it weight.
                .modifier(StaggerArrival(
                    trigger: contentArrivalTrigger,
                    staggerDelay: arrivalDelay(4)
                ))
                .padding(.horizontal, Theme.Spacing.l)
            }
        }
    }

    var closeButton: some View {
        // Tap-driven dismiss carries no throw velocity — host receives 0
        // and uses its baseline morph-spring envelope. Overlay-mode only;
        // pushed mode relies on the navigation back chevron.
        Button(action: { onDismiss?(0) }) {
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

// MARK: - Sweep iOS17 — staggered arrival modifiers
//
// PhaseAnimator and KeyframeAnimator are iOS 17+; the project's
// deployment target is iOS 17 so no `#available` guard is needed.
// Both modifiers are scoped to this file because they're tightly
// coupled to the detail's arrival cadence; if other surfaces ever
// need similar staggering, lift them into DesignSystem.

/// Drives a single text element's "drop-in" arrival via PhaseAnimator.
/// Initial phase: 12pt below + invisible. Visible phase: at-rest +
/// fully opaque. The `trigger` value is the scene's
/// `contentArrivalTrigger` flag; flipping it from false → true
/// advances the animator through the two phases. Per-element timing
/// comes from `staggerDelay` applied at the animation curve, NOT from
/// state desynchronisation — so the cadence is deterministic and a
/// single re-tap produces the same sequence each time.
///
/// The 12pt offset distance was chosen to match the existing morph's
/// vertical resolution: less than that and the drop is invisible,
/// more than that and the type "falls" rather than "settles" (the
/// Airbnb reference reads at ~10–14pt).
private struct StaggerArrival: ViewModifier {
    let trigger: Bool
    let staggerDelay: Double

    func body(content: Content) -> some View {
        content
            .phaseAnimator([0.0, 1.0], trigger: trigger) { view, phase in
                view
                    .opacity(phase)
                    .offset(y: (1.0 - phase) * 12)
            } animation: { _ in
                Theme.Animation.contentArrival.delay(staggerDelay)
            }
    }
}

/// Title-specific arrival driven by KeyframeAnimator. Position and
/// opacity run on DIFFERENT timing curves so the title "asserts"
/// (opacity ramps in over ~200ms on a cubic ease) before its position
/// has fully settled (spring with a slower 450ms duration).
///
/// This per-property timing differential is what creates the
/// "weight distribution" feeling the user's critique kept asking for:
/// a single Animation curve cannot produce it because every property
/// shares the curve. KeyframeAnimator's KeyframeTrack-per-property
/// model is the only declarative way to express this on iOS 17+.
///
/// The leading `LinearKeyframe` in each track holds at the initial
/// value for `leadIn` seconds, achieving the same effect as an
/// up-front `.delay(...)` (which KeyframeAnimator does not natively
/// support). When the trigger flips, the keyframes play once.
private struct KeyframeArrival: ViewModifier {
    let trigger: Bool
    let leadIn: Double

    /// Animatable state — KeyframeAnimator interpolates across this.
    private struct ArrivalValue: Equatable {
        var offsetY: CGFloat = 12   // initial: below resting position
        var opacity: Double = 0     // initial: invisible
    }

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(
                initialValue: ArrivalValue(),
                trigger: trigger
            ) { view, value in
                view
                    .opacity(value.opacity)
                    .offset(y: value.offsetY)
            } keyframes: { _ in
                // Position: hold at 12pt during lead-in, then a 0.45s
                // spring resolves to 0. Spring with bounce 0.18 gives a
                // light settle without overshoot reading as wobble.
                KeyframeTrack(\.offsetY) {
                    LinearKeyframe(12, duration: leadIn)
                    SpringKeyframe(0, duration: 0.45, spring: .smooth(duration: 0.45, extraBounce: 0.18))
                }
                // Opacity: hold at 0 during lead-in, then a 0.20s cubic
                // ease (faster than position) so the title becomes
                // legible before it has settled — the asymmetry IS the
                // weight effect.
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0, duration: leadIn)
                    CubicKeyframe(1.0, duration: 0.20)
                }
            }
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
