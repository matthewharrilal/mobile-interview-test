// MorphTransitionAdapter.swift
// Coordinator wrapping the three UIKit transition primitives
// (MorphPresentationController, MorphAnimatedTransitioning,
// MorphInteractionController) behind a single
// UIViewControllerTransitioningDelegate. Exposed via SwiftUI environment
// so call sites reach the adapter without depending on UIKit naming.
//
// Gating:
//   On iOS 18 the active morph is `.navigationTransition(.zoom)` —
//   the adapter stays mounted but is never asked for an animation
//   controller (no UIKit modal presentation occurs on that path).
//   On iOS 17 the adapter is the supplemental object available for
//   incremental migration of the matchedGeometryEffect overlay path.
//
// Composition with StatusBarBridgedRoot:
//   The adapter does NOT replace the existing root wrapper from
//   Sweep N. It's a sibling — call sites that opt in pull the adapter
//   from `@Environment(\.morphTransitionAdapter)` and assign it as the
//   `transitioningDelegate` of a `UIHostingController` they instantiate.

import SwiftUI
import UIKit

/// Single transitioning delegate that vends presentation controller,
/// animation controllers, and interaction controller for the morph
/// flow. One instance per session is sufficient — UIKit retains it for
/// the duration of any in-flight transition.
@MainActor
final class MorphTransitionAdapter: NSObject, UIViewControllerTransitioningDelegate {

    /// Shared interaction controller — populated by call sites at the
    /// moment they begin a drag, consumed by UIKit when it asks for an
    /// interaction controller during dismiss.
    let interactionController = MorphInteractionController()

    /// Configured morph duration. Mirrors `Theme.Animation.morphResponseSeconds`
    /// (0.25s). Stored as a primitive so this file doesn't import Theme
    /// — keeps the adapter side-effect-free for unit instantiation.
    let duration: TimeInterval

    init(duration: TimeInterval = 0.25) {
        self.duration = duration
        super.init()
    }

    // MARK: - UIViewControllerTransitioningDelegate

    func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source: UIViewController
    ) -> UIPresentationController? {
        MorphPresentationController(presentedViewController: presented, presenting: presenting)
    }

    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        MorphAnimatedTransitioning(operation: .presenting, duration: duration)
    }

    func animationController(
        forDismissed dismissed: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        MorphAnimatedTransitioning(operation: .dismissing, duration: duration)
    }

    func interactionControllerForDismissal(
        using animator: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        // Only return the interaction controller if a drag is actually in
        // flight. Returning unconditionally would make every dismiss
        // (including programmatic) interactive, which breaks tap-to-close.
        interactionController.isInteracting ? interactionController : nil
    }
}

// MARK: - Environment plumbing

private struct MorphTransitionAdapterKey: EnvironmentKey {
    /// Default is a fresh adapter per call. The real adapter is injected
    /// at the root in `ResortPassApp.swift` so it's a singleton across
    /// the scene; the default here exists for previews and unit-style
    /// view instantiation where no adapter is provided.
    @MainActor static var defaultValue: MorphTransitionAdapter { MorphTransitionAdapter() }
}

extension EnvironmentValues {
    var morphTransitionAdapter: MorphTransitionAdapter {
        get { self[MorphTransitionAdapterKey.self] }
        set { self[MorphTransitionAdapterKey.self] = newValue }
    }
}
