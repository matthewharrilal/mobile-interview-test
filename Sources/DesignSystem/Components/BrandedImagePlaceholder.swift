// BrandedImagePlaceholder.swift
// Fallback rendered when an image URL is nil or fails to load.
// Replaces the generic gray rectangle with a branded gradient + symbol so the
// empty state still feels like part of the product.

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
