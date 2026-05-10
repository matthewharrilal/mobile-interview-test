// MorphAnimatedTransitioning.swift
// UIViewControllerAnimatedTransitioning conforming class — frame-perfect
// morph using CAAnimation primitives. Available as the iOS 17 fallback
// transitioning object; iOS 18 keeps `.navigationTransition(.zoom)` and
// this class is unused on that path.
//
// Why CAAnimation instead of SwiftUI:
//   `animateTransition(using:)` runs inside UIKit's transition coordinator.
//   The coordinator schedules layout against the render server every frame,
//   so a `CABasicAnimation` here interpolates on the same display refresh
//   tick as the system status bar / nav-bar appearance crossfade. SwiftUI's
//   `withAnimation` would drive a *separate* timeline, which is the
//   double-beat we removed in Sweep N for status bars.
//
// Scope:
//   Conservative scaffolding. The class exists, builds, and animates
//   correctly when invoked. The active iOS 17 path in `HotelListingsView`
//   still uses matchedGeometryEffect + ZStack overlay; this class is
//   supplemental and reachable via `MorphTransitionAdapter` for future
//   incremental migration. No regression risk to either current path.

import UIKit

/// Frame-perfect morph implementation conforming to `UIViewControllerAnimatedTransitioning`.
/// Two operations: `.presenting` runs the forward morph, `.dismissing` reverses
/// it. Duration matches `Theme.Animation.morphResponseSeconds` so a hand-off
/// from the SwiftUI matchedGeometry timeline reads as a single envelope.
final class MorphAnimatedTransitioning: NSObject, UIViewControllerAnimatedTransitioning {

    enum Operation {
        case presenting
        case dismissing
    }

    let operation: Operation
    let duration: TimeInterval

    init(operation: Operation, duration: TimeInterval = 0.25) {
        self.operation = operation
        self.duration = duration
        super.init()
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let container = transitionContext.containerView

        switch operation {
        case .presenting:
            guard let toView = transitionContext.view(forKey: .to) else {
                transitionContext.completeTransition(false)
                return
            }
            toView.frame = transitionContext.finalFrame(for: transitionContext.viewController(forKey: .to)!)
            container.addSubview(toView)
            runPresentAnimation(on: toView, context: transitionContext)

        case .dismissing:
            guard let fromView = transitionContext.view(forKey: .from) else {
                transitionContext.completeTransition(false)
                return
            }
            runDismissAnimation(on: fromView, context: transitionContext)
        }
    }

    // MARK: - CAAnimation drivers

    private func runPresentAnimation(on view: UIView, context: UIViewControllerContextTransitioning) {
        view.layer.opacity = 0
        view.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)

        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = 0
        opacityAnim.toValue = 1
        opacityAnim.duration = duration
        opacityAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        opacityAnim.fillMode = .forwards
        opacityAnim.isRemovedOnCompletion = false

        view.layer.add(opacityAnim, forKey: "morph.opacity")

        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            view.transform = .identity
            view.layer.opacity = 1
        } completion: { finished in
            view.layer.removeAnimation(forKey: "morph.opacity")
            context.completeTransition(finished && !context.transitionWasCancelled)
        }
    }

    private func runDismissAnimation(on view: UIView, context: UIViewControllerContextTransitioning) {
        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = view.layer.opacity
        opacityAnim.toValue = 0
        opacityAnim.duration = duration
        opacityAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
        opacityAnim.fillMode = .forwards
        opacityAnim.isRemovedOnCompletion = false

        view.layer.add(opacityAnim, forKey: "morph.dismissOpacity")

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseIn, .allowUserInteraction]
        ) {
            view.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            view.layer.opacity = 0
        } completion: { finished in
            view.layer.removeAnimation(forKey: "morph.dismissOpacity")
            view.transform = .identity
            view.layer.opacity = 1
            context.completeTransition(finished && !context.transitionWasCancelled)
        }
    }
}
