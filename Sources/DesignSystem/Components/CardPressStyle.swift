// CardPressStyle.swift
// Subtle press-down feedback for tappable cards. Apple's stock UIButton ships
// a 0.97 scale; matching that here keeps tap responses native-feeling.

import SwiftUI

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
            .sensoryFeedback(.selection, trigger: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CardPressStyle {
    static var cardPress: CardPressStyle { .init() }
}
