// CardPressStyle.swift
// Subtle press-down feedback for tappable cards. Apple's stock UIButton ships
// a 0.97 scale; matching that here keeps tap responses native-feeling.

import SwiftUI

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            // Tighter, smoother release — no overshoot bounce that would
            // otherwise compete with the morph spring envelope on tap.
            .animation(.spring(response: 0.20, dampingFraction: 0.92), value: configuration.isPressed)
            .sensoryFeedback(.selection, trigger: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CardPressStyle {
    static var cardPress: CardPressStyle { .init() }
}
