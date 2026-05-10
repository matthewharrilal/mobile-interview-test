// SearchActiveOverlay.swift
// Transition 1 — search-pill blur-crossfade.
//
// Surface composition:
//   • Full-screen backdrop = .ultraThinMaterial blur over the explore content
//     beneath, with a 50% black dim layer on top. Tap-to-dismiss.
//   • Floating chrome row = back chevron + active search pill (matched-geometry
//     destination for "searchPill"). Carries `isSource: true` per the brief —
//     the host hides its own pill while presentation == .searchActive, so the
//     two `isSource: true` decls never coexist on screen.
//   • Suggestions list fades in 80ms after surface lands (.easeOut(0.22)).
//   • Keyboard appears as a separate event ~220ms post-mount via Task.sleep
//     and `@FocusState`. Per-frame focus is view-local @State, never the VM.
//
// Animation contract (from 00-build-brief.md):
//   • duration ~200ms, .easeInOut — NOT a spring
//   • backdrop blur 0 → 24pt — perceptually carried by the Material's strength
//     ramping with the overlay's `.transition(.opacity)` envelope from the host
//   • backdrop dim 1.0 → 0.5 — the Color.black.opacity(0.5) overlay layer
//   • keyboard delay 220ms — Task.sleep then fieldFocused = true
//   • suggestions delay 80ms, easeOut 0.22 — staged entry inside the surface

import SwiftUI

struct SearchActiveOverlay: View {
    @Bindable var viewModel: SearchViewModel
    let ns: Namespace.ID
    var onDismiss: () -> Void

    /// Per-frame focus state — view-local, NOT in the ViewModel. Toggled
    /// 220ms after the surface mounts so the morph completes before the
    /// keyboard climbs over it.
    @FocusState private var fieldFocused: Bool

    /// Drives the suggestions list's staged fade-in. Animated to true on
    /// appear with the brief-specified easeOut(0.22).delay(0.08) curve.
    @State private var contentVisible: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            backdrop

            VStack(spacing: 0) {
                searchBar
                Divider()
                    .background(Theme.Color.border)
                content
                    .opacity(contentVisible ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.22).delay(0.08)) {
                contentVisible = true
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(220))
            fieldFocused = true
        }
    }

    /// Brief: "Wrap call in `withAnimation(.easeInOut(duration: 0.2))`."
    /// The host's onDismiss closure ALSO wraps the state mutation in the same
    /// envelope; this inner wrap guarantees the animation even if a future
    /// caller forgets to.
    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.2)) {
            onDismiss()
        }
    }
}

// MARK: - Backdrop (blur + dim, tap-to-dismiss)

private extension SearchActiveOverlay {
    /// The backdrop sits beneath the chrome and IS the blur+dim layer the
    /// brief specifies. Taps anywhere outside the search pill / chevron /
    /// suggestion rows fall through to this view and dismiss.
    var backdrop: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(Color.black.opacity(0.5))
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { dismiss() }
            .accessibilityLabel(Text("Dismiss search"))
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Search bar pill (matched-geometry destination)

private extension SearchActiveOverlay {
    /// Back chevron + active search pill. The pill carries
    /// `matchedGeometryEffect(id: "searchPill", in: ns, isSource: true)` so
    /// the host's floating pill morphs into this active TextField.
    var searchBar: some View {
        HStack(spacing: Theme.Spacing.s) {
            Button(action: dismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.Color.textPrimary)
                    .padding(Theme.Spacing.s)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Back"))

            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: Theme.Icon.search)
                    .foregroundStyle(Theme.Color.textTertiary)
                    .accessibilityHidden(true)
                TextField("Search hotels", text: Binding(
                    get: { viewModel.state.query },
                    set: { viewModel.send(.queryChanged($0)) }
                ))
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Color.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($fieldFocused)
                .submitLabel(.search)
                .accessibilityLabel(Text("Search hotels"))
                if !viewModel.state.query.isEmpty {
                    Button { viewModel.send(.clearTapped) } label: {
                        Image(systemName: Theme.Icon.clearField)
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                    .accessibilityLabel(Text("Clear search"))
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s + 2)
            .background(Theme.Color.surfaceRecessed)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.l))
            .matchedGeometryEffect(id: "searchPill", in: ns, isSource: true)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
    }
}

// MARK: - Body content

private extension SearchActiveOverlay {
    @ViewBuilder
    var content: some View {
        switch viewModel.state.status {
        case .idle:
            idleState
        case .loading:
            loadingState
        case .loaded(let places):
            loadedState(places)
        case .empty:
            emptyState
        case .failed(let message):
            failedState(message)
        }
    }

    var idleState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer()
            Image(systemName: Theme.Icon.search)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Theme.Color.textTertiary)
            Text("Where to next?")
                .font(Theme.Typography.editorialM)
                .foregroundStyle(Theme.Color.textPrimary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    var loadingState: some View {
        VStack {
            ProgressView()
                .padding(.top, Theme.Spacing.l)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    func loadedState(_ places: [Place]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                    Button {
                        // Polish phase: bubble selection up via a callback so
                        // the host can replace the nav path. For now the VM
                        // handles it (path-based; matches existing SearchView).
                        viewModel.send(.placeSelected(place))
                    } label: {
                        placeRow(place)
                    }
                    .buttonStyle(.cardPress)
                    if index < places.count - 1 {
                        Divider()
                            .background(Theme.Color.border)
                            .padding(.leading, 64)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
        }
    }

    func placeRow(_ place: Place) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: place.iconSymbolName)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(place.isAlias ? Theme.Color.textTertiary : Theme.Color.accent)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(place.isAlias ? Theme.Color.surfaceRecessed : Theme.Color.accent.opacity(0.08))
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.system(.body, design: .serif).weight(place.isAlias ? .regular : .medium))
                    .foregroundStyle(place.isAlias ? Theme.Color.textSecondary : Theme.Color.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Text(place.typeBadge.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Theme.Color.textTertiary)
            }
            Spacer(minLength: Theme.Spacing.s)
            Image(systemName: Theme.Icon.chevronRight)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Color.textTertiary.opacity(0.6))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, Theme.Spacing.m)
        .contentShape(Rectangle())
    }

    var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer()
            Text("No matches for \"\(viewModel.state.query)\"")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Color.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    func failedState(_ message: String) -> some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer()
            Image(systemName: Theme.Icon.warning)
                .foregroundStyle(Theme.Color.danger)
            Text(message)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.l)
            Button("Try again") { viewModel.send(.retryTapped) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Color.accent)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview("SearchActiveOverlay") {
    SearchActiveOverlayPreviewWrapper()
}

private struct SearchActiveOverlayPreviewWrapper: View {
    @Namespace var ns

    var body: some View {
        SearchActiveOverlay(
            viewModel: SearchViewModel(client: .preview),
            ns: ns,
            onDismiss: {}
        )
    }
}
