// StatusBarBridgeHostingController.swift
// UIHostingController subclass that bridges SwiftUI → UIKit status-bar
// appearance so the iOS 17 fallback morph (matchedGeometryEffect + ZStack
// overlay in HotelListingsView) can transition the system status bar from
// `.darkContent` to `.lightContent` on the same envelope as the morph
// spring (Theme.Animation.morphSpring).
//
// Why a bridge:
//   SwiftUI's `.statusBarHidden` / `.statusBar(hidden:)` modifiers fire
//   on a different timeline from a `withAnimation(spring)` envelope —
//   the bar style snaps mid-morph and reads as a perceptual "double
//   beat" against the geometry change. This file owns
//   `preferredStatusBarStyle` so a single `setNeedsStatusBarAppearanceUpdate()`
//   call wrapped in `UIView.animate(withDuration:)` runs in lock-step with
//   the spring's response window.
//
// iOS 18 path:
//   `.navigationTransition(.zoom)` handles status-bar coordination
//   natively. The bridge stays mounted but is never invoked — call sites
//   gate on `useZoomTransitionPath` so the bridge is a strict iOS 17
//   fallback artifact.
//
// Mounting choice:
//   The root view in `ResortPassApp.swift` is wrapped in
//   `StatusBarBridgedRoot` (a UIViewControllerRepresentable). The bridge
//   HC becomes a child of SwiftUI's outer hosting controller. UIKit's
//   `childForStatusBarStyle` traversal honors the topmost descendant
//   that overrides `preferredStatusBarStyle`, so our subclass wins.
//   This is the smaller-diff approach — it preserves the existing
//   `WindowGroup`/`@main App` lifecycle instead of rewriting the entry
//   point with a UIApplicationDelegateAdaptor + UIWindowSceneDelegate.

import SwiftUI
import UIKit

// MARK: - Bridge protocol

/// Type-erased entry point for the generic `StatusBarBridgeHostingController`.
/// `StatusBarStyleAnimator` holds a weak reference through this protocol so
/// it doesn't have to know the bridge's `Content` generic parameter.
@MainActor
protocol StatusBarBridgeHostingControllerProtocol: AnyObject {
    func animateStatusBarStyle(_ style: UIStatusBarStyle, duration: TimeInterval)
}

// MARK: - Hosting controller

/// `UIHostingController` subclass whose `preferredStatusBarStyle` is
/// driven by a stored `UIStatusBarStyle` and whose updates are run inside
/// a `UIView.animate(withDuration:)` block so the system's status-bar
/// appearance crossfade lines up with the SwiftUI morph spring.
///
/// The default style is `.darkContent` to match the listings/explore
/// surface (light backgrounds → dark text). The detail hero is a dark
/// photographic surface, so it transitions to `.lightContent` while the
/// morph is in flight, then back to `.darkContent` on dismiss.
final class StatusBarBridgeHostingController<Content: View>: UIHostingController<Content>, StatusBarBridgeHostingControllerProtocol {
    private var currentStyle: UIStatusBarStyle = .darkContent

    override var preferredStatusBarStyle: UIStatusBarStyle { currentStyle }

    /// Set the new style, then ask UIKit to animate the appearance update
    /// across `duration`. The animation block does no view work itself —
    /// `setNeedsStatusBarAppearanceUpdate()` is what schedules UIKit's
    /// internal status-bar crossfade against the surrounding curve. Pairing
    /// it with `UIView.animate` is the documented way to bind that
    /// crossfade to a custom duration.
    func animateStatusBarStyle(_ style: UIStatusBarStyle, duration: TimeInterval) {
        guard style != currentStyle else { return }
        currentStyle = style
        UIView.animate(withDuration: duration) { [weak self] in
            self?.setNeedsStatusBarAppearanceUpdate()
        }
    }
}

// MARK: - Animator (SwiftUI-side handle)

/// SwiftUI-facing handle that call sites (e.g. `HotelListingsView`)
/// reach through `@Environment(\.statusBarStyleAnimator)` to drive the
/// bridge HC. Holds a weak reference to the controller so the SwiftUI
/// scene's lifecycle continues to own the controller.
@MainActor
final class StatusBarStyleAnimator {
    weak var hostingController: (any StatusBarBridgeHostingControllerProtocol)?

    init() {}

    /// Animate the status-bar style across `duration`. No-ops if the
    /// bridge HC is not yet attached (e.g. previews) — the call site is
    /// expected to be a layout/animation cosmetic, not a correctness
    /// dependency.
    func setStyle(_ style: UIStatusBarStyle, duration: TimeInterval) {
        hostingController?.animateStatusBarStyle(style, duration: duration)
    }
}

// MARK: - Environment plumbing

private struct StatusBarStyleAnimatorKey: EnvironmentKey {
    /// Default is a detached animator with no controller — calls become
    /// no-ops. The real animator is injected at the root in
    /// `ResortPassApp.swift`.
    @MainActor static var defaultValue: StatusBarStyleAnimator { StatusBarStyleAnimator() }
}

extension EnvironmentValues {
    var statusBarStyleAnimator: StatusBarStyleAnimator {
        get { self[StatusBarStyleAnimatorKey.self] }
        set { self[StatusBarStyleAnimatorKey.self] = newValue }
    }
}

// MARK: - Representable wrapper

/// Wraps the SwiftUI root in a `UIHostingController` subclass that owns
/// `preferredStatusBarStyle`. Mounted from `ResortPassApp` inside the
/// existing `WindowGroup` so the bridge HC becomes a descendant of
/// SwiftUI's outer hosting controller. UIKit walks `childForStatusBarStyle`
/// down the chain and lands on this controller — its overridden
/// `preferredStatusBarStyle` is what the system queries.
struct StatusBarBridgedRoot<Content: View>: UIViewControllerRepresentable {
    let animator: StatusBarStyleAnimator
    let content: Content

    init(animator: StatusBarStyleAnimator, @ViewBuilder content: () -> Content) {
        self.animator = animator
        self.content = content()
    }

    func makeUIViewController(context: Context) -> StatusBarBridgeHostingController<Content> {
        let vc = StatusBarBridgeHostingController(rootView: content)
        animator.hostingController = vc
        return vc
    }

    func updateUIViewController(_ uiViewController: StatusBarBridgeHostingController<Content>, context: Context) {
        uiViewController.rootView = content
    }
}
