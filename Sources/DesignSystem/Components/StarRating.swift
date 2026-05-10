// StarRating.swift
// Renders a 0–5 rating as five filled / half-filled / empty star glyphs.
// Visual texture beats a bare numeric — at-a-glance, the user sees quality.

import SwiftUI

struct StarRating: View {
    let value: Double
    var size: CGFloat = 12
    var filledColor: Color = Color(red: 0.96, green: 0.62, blue: 0.04)   // warm amber
    var emptyColor: Color = Theme.Color.textTertiary.opacity(0.35)

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<5, id: \.self) { index in
                star(for: index)
                    .font(.system(size: size, weight: .semibold))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(String(format: "Rated %.1f out of 5", value)))
    }

    @ViewBuilder
    private func star(for index: Int) -> some View {
        let position = Double(index)
        if value >= position + 1 {
            Image(systemName: "star.fill").foregroundStyle(filledColor)
        } else if value >= position + 0.5 {
            Image(systemName: "star.leadinghalf.filled").foregroundStyle(filledColor)
        } else {
            Image(systemName: "star").foregroundStyle(emptyColor)
        }
    }
}
