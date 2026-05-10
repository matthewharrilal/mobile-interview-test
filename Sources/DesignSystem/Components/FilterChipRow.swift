// FilterChipRow.swift
// Horizontally scrolling filter chip row that pins below the nav bar.
// Each chip is a SF-symbol + label pill with selected/unselected states.

import SwiftUI

struct FilterChipRow: View {
    let filters: [HotelListingsState.Filter]
    @Binding var selected: HotelListingsState.Filter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(filters) { filter in
                    FilterChip(
                        filter: filter,
                        isSelected: filter == selected,
                        action: {
                            withAnimation(Theme.Animation.selectionFeedback) { selected = filter }
                        }
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
        }
        .scrollClipDisabled()
    }
}

private struct FilterChip: View {
    let filter: HotelListingsState.Filter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.iconName)
                    .font(.system(size: 12, weight: .medium))
                Text(filter.displayName)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.white : Theme.Color.textPrimary)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s + 1)
            .background(
                Capsule().fill(
                    isSelected
                    ? AnyShapeStyle(LinearGradient(
                        colors: [Theme.Color.accent, Theme.Color.accent.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    : AnyShapeStyle(Theme.Color.surface)
                )
            )
            .overlay(
                Capsule().stroke(
                    isSelected ? Color.clear : Theme.Color.border,
                    lineWidth: 0.5
                )
            )
            .shadow(
                color: isSelected ? Theme.Color.accent.opacity(0.25) : Color.black.opacity(0.04),
                radius: isSelected ? 6 : 2,
                x: 0,
                y: isSelected ? 3 : 1
            )
        }
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
