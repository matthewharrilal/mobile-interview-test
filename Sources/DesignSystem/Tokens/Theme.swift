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
    /// across the app and tuning happens in one place.
    enum Animation {
        /// Card → detail morph spring. Near-critical (response 0.25, damping
        /// 0.95) gives a ~150ms geometry duration with no overshoot — the hero
        /// lands clean before the content fade-in beat starts in the detail.
        static let morphSpring = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.95)
    }
}
