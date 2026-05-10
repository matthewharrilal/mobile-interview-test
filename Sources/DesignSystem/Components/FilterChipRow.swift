// FilterChipRow.swift
// Horizontally scrolling filter chip row that pins below the nav bar.
// Each chip is a SF-symbol + label pill with selected/unselected states.
//
// Cohesion-supplemental (CALayer / CAAnimation): selection toggles a
// CABasicAnimation-driven border-width pulse on a sibling CALayer behind
// the chip. The pulse runs frame-precise (CoreAnimation owns the timeline,
// not SwiftUI's transaction system) and reads as a subtle "ring of
// confirmation" when a chip enters the selected state. Lives entirely on
// non-matched-geometry siblings so it cannot interfere with the card →
// detail morph or `.zoom` navigation transition.

import SwiftUI
import UIKit

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
                    // Semantic .footnote so chip labels scale with
                    // Dynamic Type at large accessibility sizes.
                    .font(.footnote.weight(.medium))
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
                    lineWidth: Theme.Spacing.hairline   // single physical pixel — crisp on @2x and @3x
                )
            )
            // Supplemental CALayer/CAAnimation pulse — only paints when
            // the chip is selected, only animates on the rising edge.
            // The CABasicAnimation runs CoreAnimation-side (frame-precise)
            // for a single border-width tick; in steady state the layer
            // is invisible. Sibling-layer placement (overlay, not the
            // capsule fill itself) keeps the visible Capsule untouched.
            .overlay(
                ChipSelectionPulse(isSelected: isSelected, accent: Theme.Color.accent)
                    .allowsHitTesting(false)
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

// MARK: - CALayer / CAAnimation supplemental pulse

/// UIViewRepresentable bridge that hosts a `CALayer` whose `borderWidth`
/// is animated via `CABasicAnimation` on the rising edge of `isSelected`.
/// The CoreAnimation timeline runs frame-precise (vBlank-aligned, runs at
/// ProMotion 120 Hz on supported devices) — distinct from SwiftUI's
/// transaction-driven animation system.
///
/// Safety: this lives in a SwiftUI `.overlay` on the chip body, never on
/// elements wearing `.matchedGeometryEffect` or `.matchedTransitionSource`
/// — so it does not contend for transition layer ownership.
private struct ChipSelectionPulse: UIViewRepresentable {
    let isSelected: Bool
    let accent: SwiftUI.Color

    func makeUIView(context: Context) -> ChipPulseView {
        ChipPulseView()
    }

    func updateUIView(_ view: ChipPulseView, context: Context) {
        view.update(isSelected: isSelected, accent: UIColor(accent))
    }
}

/// Hand-rolled UIView that owns a CALayer and runs a CABasicAnimation when
/// the selection rising-edge is observed. Layer-side animation only — no
/// `UIView.animate` or SwiftUI transactions involved.
private final class ChipPulseView: UIView {
    private var lastSelected: Bool = false

    override class var layerClass: AnyClass { CALayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        layer.borderWidth = 0
        layer.borderColor = UIColor.clear.cgColor
        // Rounded — the chip's pill shape. Capsule corner radius matches
        // SwiftUI's Capsule (height/2 at layout time).
        layer.masksToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Match SwiftUI Capsule shape — corner radius = half of shorter
        // dimension. Updates per-layout so the pill stays pill-shaped at
        // any size class.
        layer.cornerRadius = bounds.height / 2
    }

    func update(isSelected: Bool, accent: UIColor) {
        guard isSelected != lastSelected else { return }
        lastSelected = isSelected
        guard isSelected else {
            // Falling edge — clear the border instantly. No need to
            // animate the un-selection (selectionFeedback handles it).
            layer.removeAnimation(forKey: "selectionPulse")
            layer.borderWidth = 0
            return
        }

        // Rising edge: animate borderWidth from 3 → 0 over 280ms with a
        // CASpringAnimation envelope so the pulse decays naturally rather
        // than linearly. The model value lands at 0 (steady state) so the
        // animation is a one-shot decoration, not a persistent border.
        layer.borderColor = accent.withAlphaComponent(0.55).cgColor
        layer.borderWidth = 0   // model value (steady state)

        let pulse = CASpringAnimation(keyPath: "borderWidth")
        pulse.fromValue = 3.0
        pulse.toValue = 0.0
        pulse.damping = 14
        pulse.stiffness = 180
        pulse.mass = 1.0
        pulse.initialVelocity = 0.0
        pulse.duration = pulse.settlingDuration
        pulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
        pulse.isRemovedOnCompletion = true
        layer.add(pulse, forKey: "selectionPulse")
    }
}
