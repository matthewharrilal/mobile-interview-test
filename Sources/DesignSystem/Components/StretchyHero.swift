// StretchyHero.swift
// Modifiers + scrim helper for the premium pull-to-refresh hero pattern.
// Per the research: bottom-anchored visualEffect scale, 3-stop scrim,
// material chrome — composes into a no-white-gap, no-hard-edge hero.

import SwiftUI

extension View {
    /// Bottom-anchored stretchy hero. Image grows on overscroll while
    /// content below stays put. Computes its transform on the GPU compositor
    /// thread via `visualEffect` — no preference keys, no @State, no jank.
    func stretchyHero() -> some View {
        visualEffect { content, proxy in
            let height = proxy.size.height
            let minY = proxy.frame(in: .scrollView(axis: .vertical)).minY
            let isStretching = minY > 0
            let scale = isStretching ? (height + minY) / max(height, 1) : 1.0
            return content
                .scaleEffect(x: scale, y: scale, anchor: .bottom)
        }
    }

    /// Editorial 3-stop scrim — fades the hero image down into the screen
    /// background. The 3-stop curve hides the perceptible midline that a
    /// 2-stop gradient leaves behind.
    func editorialScrim(toColor: Color, height: CGFloat = 120) -> some View {
        overlay(alignment: .bottom) {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: toColor.opacity(0.55), location: 0.55),
                    .init(color: toColor, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)
            .allowsHitTesting(false)
        }
    }

    /// PreferenceKey-based scroll-offset tracker for iOS 17. Wrap a view
    /// inside a `coordinateSpace`-named ScrollView and call this on the
    /// content; reports the negative top inset (positive when scrolled down).
    func trackScrollOffset(in space: String, action: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ScrollOffsetKey.self,
                                value: -proxy.frame(in: .named(space)).minY)
            }
        )
        .onPreferenceChange(ScrollOffsetKey.self, perform: action)
    }
}

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
