// Theme.swift
// Two-tier design tokens: Palette (raw values) → Theme (semantic aliases).
// Inline color/spacing literals in Sources/ are forbidden and grep-gated.

import SwiftUI

// MARK: - Palette (raw)

private enum Palette {
    static let blue500 = Color(red: 0.231, green: 0.510, blue: 0.945)
    static let blue400 = Color(red: 0.376, green: 0.651, blue: 0.965)
    static let neutral000 = Color(red: 0.980, green: 0.980, blue: 0.980)
    static let neutral050 = Color(red: 0.957, green: 0.957, blue: 0.961)
    static let neutral100 = Color(red: 0.898, green: 0.898, blue: 0.906)
    static let neutral400 = Color(red: 0.631, green: 0.631, blue: 0.631)
    static let neutral600 = Color(red: 0.420, green: 0.420, blue: 0.420)
    static let neutral900 = Color(red: 0.090, green: 0.090, blue: 0.090)
    static let red500 = Color(red: 0.937, green: 0.267, blue: 0.267)
    static let amber500 = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let green500 = Color(red: 0.133, green: 0.773, blue: 0.369)
}

// MARK: - Theme.Color (semantic)

enum Theme {
    enum Color {
        /// Page background — used at the root of every screen.
        static let background = Palette.neutral000
        /// Card/elevated surface background.
        static let surface = SwiftUI.Color.white
        /// Primary text — headlines, body copy.
        static let textPrimary = Palette.neutral900
        /// Secondary text — metadata, supporting copy.
        static let textSecondary = Palette.neutral600
        /// Tertiary text — de-emphasised content.
        static let textTertiary = Palette.neutral400
        /// Subtle border — only used where whitespace alone is insufficient.
        static let border = Palette.neutral100
        /// Recessed surface — search-bar fill, input chrome.
        static let surfaceRecessed = Palette.neutral050
        /// Brand accent — links, primary buttons, focus ring.
        static let accent = Palette.blue500
        /// Semantic status colors.
        static let danger = Palette.red500
        static let warning = Palette.amber500
        static let success = Palette.green500
    }

    // MARK: - Spacing

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

    // MARK: - Typography

    enum Typography {
        static let titleL = Font.system(size: 32, weight: .medium)
        static let titleM = Font.system(size: 24, weight: .medium)
        static let titleS = Font.system(size: 17, weight: .medium)
        static let body = Font.system(size: 16, weight: .regular)
        static let bodyEmphasised = Font.system(size: 16, weight: .medium)
        static let footnote = Font.system(size: 13, weight: .regular)
        static let caption = Font.system(size: 12, weight: .regular)
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
}
