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
        /// Semantic status colors.
        static let danger = SwiftUI.Color("danger", bundle: .main)
        static let warning = SwiftUI.Color("warning", bundle: .main)
        static let success = SwiftUI.Color("success", bundle: .main)
    }

    // MARK: - Spacing (8pt grid)

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let s: CGFloat = 6
        static let m: CGFloat = 8
        static let l: CGFloat = 12
        static let pill: CGFloat = 9999
    }

    // MARK: - Typography (Dynamic Type aware)

    /// Semantic font styles that respect Dynamic Type. Each maps to a system
    /// text style so the user's accessibility size scales them automatically.
    enum Typography {
        static let titleL = Font.largeTitle.weight(.medium)
        static let titleM = Font.title2.weight(.medium)
        static let titleS = Font.headline
        static let body = Font.body
        static let bodyEmphasised = Font.body.weight(.medium)
        static let footnote = Font.footnote
        static let caption = Font.caption
    }

    // MARK: - Elevation

    enum Elevation {
        static let card = (
            color: SwiftUI.Color.black.opacity(0.06),
            radius: CGFloat(3),
            x: CGFloat(0),
            y: CGFloat(1)
        )
    }

    // MARK: - Icons

    /// Centralized SF Symbol names. Every Image(systemName:) usage routes
    /// through here so renames are localized to one file.
    enum Icon {
        static let search = "magnifyingglass"
        static let clearField = "xmark.circle.fill"
        static let chevronRight = "chevron.right"
        static let mapPin = "mappin.circle.fill"
        static let star = "star.fill"
        static let vibe = "sparkles"
        static let warning = "exclamationmark.triangle"
        static let houseSlash = "house.slash"
    }
}
