// Theme.swift
// Two-tier semantic design tokens. Colors live in Assets.xcassets with explicit
// Light + Dark variants, so the entire app adapts automatically to system appearance.
// Inline color/font literals in Sources/ are forbidden and grep-gated.

import SwiftUI

enum Theme {

    // MARK: - Color (Asset Catalog–backed; light + dark variants)

    enum Color {
        /// Page background — root of every screen.
        static let background = SwiftUI.Color("background", bundle: .main)
        /// Card / elevated surface background.
        static let surface = SwiftUI.Color("surface", bundle: .main)
        /// Recessed surface — search-bar fill, input chrome.
        static let surfaceRecessed = SwiftUI.Color("surfaceRecessed", bundle: .main)
        /// Primary text — headlines, body copy.
        static let textPrimary = SwiftUI.Color("textPrimary", bundle: .main)
        /// Secondary text — metadata, supporting copy.
        static let textSecondary = SwiftUI.Color("textSecondary", bundle: .main)
        /// Tertiary text — de-emphasised content.
        static let textTertiary = SwiftUI.Color("textTertiary", bundle: .main)
        /// Subtle border — only used where whitespace alone is insufficient.
        static let border = SwiftUI.Color("border", bundle: .main)
        /// Brand accent — links, primary buttons, focus ring.
        static let accent = SwiftUI.Color("accent", bundle: .main)
        /// Semantic status — destructive actions, errors.
        static let danger = SwiftUI.Color("danger", bundle: .main)
    }

    // MARK: - Spacing (8pt grid)

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let s: CGFloat = 6
        static let l: CGFloat = 12
    }

    // MARK: - Typography (Dynamic Type aware)

    /// Semantic font styles that respect Dynamic Type. Each maps to a system
    /// text style so the user's accessibility size scales them automatically.
    /// Editorial typography: hotel + place names use Playfair Display
    /// (bundled OFL-licensed display serif). Supporting copy stays in SF Pro.
    enum Typography {
        static let body = Font.body

        /// Editorial display serif (Playfair Display) for hotel + place names.
        /// Falls back to system serif (.system(...,design: .serif)) if the font
        /// fails to load, so the layout always renders.
        static let editorialL = Font.custom("PlayfairDisplay-Regular", size: 24, relativeTo: .title2).weight(.medium)
        static let editorialM = Font.custom("PlayfairDisplay-Regular", size: 20, relativeTo: .title3).weight(.medium)
        static let editorialDisplay = Font.custom("PlayfairDisplay-Regular", size: 28, relativeTo: .title).weight(.semibold)

        /// Refined supporting copy — uppercase metadata + numeric prices.
        static let metadata = Font.system(.footnote).weight(.medium)
        static let priceDisplay = Font.custom("PlayfairDisplay-Regular", size: 22, relativeTo: .title3).weight(.semibold)
    }

    // MARK: - Elevation

    /// Layered shadow system. Real elevation comes from stacking a tight
    /// ambient shadow (close, soft) on top of a wider cast shadow (offset,
    /// diffuse). Single-shadow cards always look flat under direct light.
    enum Elevation {
        /// Subtle ambient shadow — adds the close-up "lift" off the surface.
        static let cardAmbient = (
            color: SwiftUI.Color.black.opacity(0.06),
            radius: CGFloat(3),
            x: CGFloat(0),
            y: CGFloat(1)
        )
        /// Wider cast shadow — adds the cinematic depth at distance.
        static let cardCast = (
            color: SwiftUI.Color.black.opacity(0.10),
            radius: CGFloat(18),
            x: CGFloat(0),
            y: CGFloat(8)
        )
        /// Floating chip elevation — for price pills overlapping the card edge.
        static let floatingChip = (
            color: SwiftUI.Color.black.opacity(0.16),
            radius: CGFloat(10),
            x: CGFloat(0),
            y: CGFloat(4)
        )
    }

    // MARK: - Icons

    /// Centralized SF Symbol names. Every Image(systemName:) usage routes
    /// through here so renames are localized to one file.
    enum Icon {
        static let search = "magnifyingglass"
        static let clearField = "xmark.circle.fill"
        static let chevronRight = "chevron.right"
        static let star = "star.fill"
        static let warning = "exclamationmark.triangle"
        static let houseSlash = "house.slash"
    }

    // MARK: - Animation

    /// Named animation curves. Centralized so transitions stay consistent
    /// across the app and tuning happens in one place. Names describe
    /// INTENT (what is animating) not duration — duration is an
    /// implementation detail that can be tuned in this file alone.
    ///
    /// Cohesion contract: every `withAnimation`, `.animation(...)`, and
    /// `.transition(...)` modifier in `Sources/` MUST reference one of
    /// these tokens. Inline curve literals (`.snappy(...)`, `.spring(...)`,
    /// `.easeOut(...)`) are forbidden — they fragment the cadence and
    /// defeat single-source-of-truth tuning.
    enum Animation {
        /// Card → detail morph spring. Near-critical (response 0.25, damping
        /// 0.95) gives a ~150ms geometry duration with no overshoot — the hero
        /// lands clean before the content fade-in beat starts in the detail.
        static let morphSpring = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.95)

        /// Content reveal inside the detail surface — fade-in coordinated
        /// with the morph landing (`.delay(0.16)` is applied at the call
        /// site so the beat lands ~160ms after mount). Linear-ease tail
        /// keeps the type-bloom subtle next to the spring.
        static let contentReveal = SwiftUI.Animation.easeOut(duration: 0.25)

        /// Selection feedback for filter chips and reset buttons. Snappy
        /// (no overshoot) so multiple rapid taps stay responsive without
        /// stacking bounces.
        static let selectionFeedback = SwiftUI.Animation.snappy(duration: 0.25)

        /// Press-down feedback for tappable cards (`CardPressStyle`).
        /// Tighter response and higher damping than morphSpring so the
        /// release doesn't overshoot and compete with an in-flight morph.
        static let pressFeedback = SwiftUI.Animation.spring(response: 0.20, dampingFraction: 0.92)

        /// Surface mount/unmount crossfade — applied to status-state
        /// transitions (loaded/empty/failed) and to `.transition(.opacity)`
        /// curves so they don't run on SwiftUI's default 0.35s ease.
        static let surfaceCrossfade = SwiftUI.Animation.easeInOut(duration: 0.20)

        /// Quick polish fade — short cosmetic fades (image swaps, etc.).
        /// Aligned with Kingfisher's fade duration so image-load reveals
        /// match the rest of the animation cadence.
        static let quickFade = SwiftUI.Animation.easeInOut(duration: 0.20)

        /// Rubber-band snap-back for cancelled drag-dismiss gestures.
        /// Heavier-damped interpolating spring — the user already saw the
        /// movement, so no overshoot is needed on return.
        static let snapBack = SwiftUI.Animation.interpolatingSpring(stiffness: 200, damping: 20)

        /// KFImage's `.fade(duration:)` takes a `Double` and runs through
        /// `CATransition`, which cannot consume a SwiftUI `Animation`.
        /// Use this constant so every Kingfisher call site stays in
        /// lockstep with `quickFade` / `surfaceCrossfade` (both 0.20s).
        /// Single source of truth for image-load reveal cadence.
        static let kfFadeDuration: TimeInterval = 0.20
    }
}
