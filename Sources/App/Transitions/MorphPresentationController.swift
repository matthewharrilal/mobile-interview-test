// MorphPresentationController.swift
// UIPresentationController subclass that owns the dimming backdrop and
// container layering during the iOS 17 fallback morph. Decouples the
// chrome (dimming + layer ordering) from the destination view's own
// matchedGeometry transform, so a future migration can swap the
// destination animation without re-implementing the dimming layer.
//
// Active path:
//   Currently scaffolded. The active iOS 17 morph in HotelListingsView
//   uses an inline ZStack overlay for dimming; this controller is the
//   supplemental UIKit-side equivalent, reachable via
//   `MorphTransitionAdapter` for incremental migration.

import UIKit

/// Provides a dimming layer below the presented view and full-bounds
/// frame for the presented view. Animates dimming alpha alongside the
/// transition coordinator so the backdrop fades on the same envelope
/// as `MorphAnimatedTransitioning`'s opacity curve.
final class MorphPresentationController: UIPresentationController {

    private let dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.32)
        view.alpha = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override var frameOfPresentedViewInContainerView: CGRect {
        containerView?.bounds ?? .zero
    }

    override func presentationTransitionWillBegin() {
        guard let containerView else { return }
        containerView.insertSubview(dimmingView, at: 0)
        NSLayoutConstraint.activate([
            dimmingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        guard let coordinator = presentingViewController.transitionCoordinator else {
            dimmingView.alpha = 1
            return
        }
        coordinator.animate(alongsideTransition: { [dimmingView] _ in
            dimmingView.alpha = 1
        })
    }

    override func dismissalTransitionWillBegin() {
        guard let coordinator = presentingViewController.transitionCoordinator else {
            dimmingView.alpha = 0
            return
        }
        coordinator.animate(alongsideTransition: { [dimmingView] _ in
            dimmingView.alpha = 0
        })
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed {
            dimmingView.removeFromSuperview()
        }
    }

    override func containerViewWillLayoutSubviews() {
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
}
