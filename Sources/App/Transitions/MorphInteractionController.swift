// MorphInteractionController.swift
// UIPercentDrivenInteractiveTransition subclass that exposes a clean
// SwiftUI-facing percent driver for interactive dismiss. UIKit's
// transition machinery interpolates against display refresh, which —
// paired with the CADisplayLink driver in EditorialGradeProcessor /
// HotelDetailScene's snap-back — gives frame-perfect dismiss timing
// in the iOS 17 fallback path.
//
// Active path:
//   Scaffolded. The active iOS 17 dismiss flow drives a SwiftUI @State
//   `dismissProgress` directly. This controller is the UIKit-side
//   supplement, reachable via `MorphTransitionAdapter`. Future migration
//   can route gesture progress through `update(progress:)` instead of
//   the SwiftUI @State path.

import UIKit

/// Percent-driven interactive transition with explicit `update(progress:)` /
/// `complete()` / `abort()` API for drag-driven dismiss. Wraps UIKit's
/// `update(_:)`, `finish()`, `cancel()` so call sites don't depend on
/// UIKit naming.
final class MorphInteractionController: UIPercentDrivenInteractiveTransition {

    /// Mark the transition as currently in flight. The transitioning
    /// delegate consults this to decide whether to return an interaction
    /// controller from `interactionControllerForDismissal(using:)`.
    private(set) var isInteracting: Bool = false

    func begin() {
        isInteracting = true
    }

    func update(progress: CGFloat) {
        update(max(0, min(1, progress)))
    }

    func complete() {
        isInteracting = false
        finish()
    }

    func abort() {
        isInteracting = false
        cancel()
    }
}
