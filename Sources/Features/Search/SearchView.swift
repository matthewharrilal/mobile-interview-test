// SearchView.swift
// SwiftUI view for the Search screen — search bar at top, content body per Status.
// Place rows use type-aware icons (city / country / alias) for visual differentiation.

import SwiftUI

// MARK: - Body

struct SearchView: View {
    @Bindable var viewModel: SearchViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
                .background(Theme.Color.border)
            content
        }
        .background(Theme.Color.background)
        .navigationTitle(Strings.Search.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        // F12-05: in landscape (and any compact-height layout), the on-screen
        // keyboard can occlude the failed/empty state's primary CTA ("Try Again").
        // Resign first responder when entering .failed or .empty so the recovery
        // affordance is reachable without requiring the user to discover an
        // undocumented swipe-to-dismiss gesture.
        .onChange(of: viewModel.state.status) { _, newStatus in
            switch newStatus {
            case .failed, .failedNullCoords, .empty:
                searchFocused = false
            case .idle, .loading, .loaded:
                break
            }
        }
    }
}

// MARK: - Subviews

private extension SearchView {
    var searchBar: some View {
        HStack(spacing: Theme.Spacing.s) {
            if case .loading = viewModel.state.status {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(Text("Loading"))
            } else {
                Image(systemName: Theme.Icon.search)
                    .foregroundStyle(Theme.Color.textTertiary)
                    .accessibilityHidden(true)
            }
            TextField(Strings.Search.placeholder, text: Binding(
                get: { viewModel.state.query },
                set: { viewModel.send(.queryChanged($0)) }
            ))
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Color.textPrimary)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($searchFocused)
            .accessibilityLabel(Strings.Accessibility.searchField)
            if !viewModel.state.query.isEmpty {
                Button { viewModel.send(.clearTapped) } label: {
                    Image(systemName: Theme.Icon.clearField)
                        .foregroundStyle(Theme.Color.textTertiary)
                }
                .accessibilityLabel(Strings.Accessibility.clearSearch)
            }
        }
        .sensoryFeedback(.selection, trigger: viewModel.state.clearCount)
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s + 2)
        .background(Theme.Color.surfaceRecessed)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.l))
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
    }

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
        case .failedNullCoords(let placeName):
            failedNullCoordsState(placeName)
        }
    }

    var idleState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer()
            Image(systemName: Theme.Icon.search)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.Color.textTertiary)
                .accessibilityHidden(true)
            Text(Strings.Search.idleHeadline)
                .font(Theme.Typography.editorialL)
                .foregroundStyle(Theme.Color.textPrimary)
            Text(Strings.Search.idleSubtitle)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Color.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.l)
        .accessibilityElement(children: .combine)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    var loadingState: some View {
        VStack(spacing: Theme.Spacing.s) {
            ForEach(0..<3, id: \.self) { _ in
                skeletonRow
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.top, Theme.Spacing.s)
        .accessibilityLabel(Text("Loading places"))
    }

    var skeletonRow: some View {
        HStack(spacing: Theme.Spacing.m) {
            Circle()
                .fill(Theme.Color.surfaceRecessed)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                RoundedRectangle(cornerRadius: Theme.CornerRadius.s)
                    .fill(Theme.Color.surfaceRecessed)
                    .frame(height: 18)
                    .frame(maxWidth: 220)
                RoundedRectangle(cornerRadius: Theme.CornerRadius.s)
                    .fill(Theme.Color.surfaceRecessed)
                    .frame(height: 14)
                    .frame(maxWidth: 140)
            }
            Spacer()
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.l))
    }

    func loadedState(_ places: [Place]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                    Button { viewModel.send(.placeSelected(place)) } label: {
                        placeRow(place)
                    }
                    .buttonStyle(.cardPress)
                    .accessibilityHint(Text(String(format: Strings.Accessibility.placeRowHintFormat, place.name)))
                    if index < places.count - 1 {
                        Divider()
                            .background(Theme.Color.border)
                            .padding(.leading, 64)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.xs)
        }
        .transition(.opacity)
    }

    func placeRow(_ place: Place) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            // Type-aware icon — outlined SF Symbol for editorial restraint
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
        // F12-05: wrap in a ScrollView so the content remains reachable when
        // the keyboard is shown (e.g. landscape / compact-height). Pairs with
        // .scrollDismissesKeyboard(.immediately) on the parent VStack — any
        // user-driven scroll also dismisses the keyboard.
        ScrollView {
            ContentUnavailableView(
                Strings.Search.emptyHeadline,
                systemImage: Theme.Icon.search,
                description: Text(String(format: Strings.Search.emptyDescriptionFormat, viewModel.state.query))
            )
            .frame(maxWidth: .infinity, minHeight: keyboardSafeMinHeight)
        }
        .transition(.opacity)
    }

    func failedState(_ message: String) -> some View {
        // F12-05: wrap in a ScrollView so the "Try Again" CTA is reachable even
        // if the keyboard re-appears. The .onChange handler in `body` also
        // resigns first responder on entering .failed so the CTA is visible
        // immediately without requiring the user to scroll.
        ScrollView {
            ContentUnavailableView {
                Label(Strings.Search.failedHeadline, systemImage: Theme.Icon.warning)
                    .foregroundStyle(Theme.Color.danger)
            } description: {
                Text(message)
            } actions: {
                Button(Strings.Search.tryAgain) { viewModel.send(.retryTapped) }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Color.accent)
            }
            .frame(maxWidth: .infinity, minHeight: keyboardSafeMinHeight)
        }
        .transition(.opacity)
    }

    /// Distinct from `failedState`: the user picked a place we can't navigate to
    /// (null coords). "Try Again" against the same query is a dead-end, so the
    /// CTA clears the query, returns to idle, and refocuses the input field.
    func failedNullCoordsState(_ placeName: String) -> some View {
        ContentUnavailableView {
            Label(Strings.Search.nullCoordsHeadline, systemImage: Theme.Icon.warning)
                .foregroundStyle(Theme.Color.danger)
        } description: {
            Text(String(format: Strings.Search.nullCoordsFormat, placeName))
        } actions: {
            Button(Strings.Search.nullCoordsCTA) {
                viewModel.send(.clearSearch)
                searchFocused = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Color.accent)
        }
        .frame(maxWidth: .infinity, minHeight: keyboardSafeMinHeight)
        .transition(.opacity)
    }

    /// Minimum content height for failed/empty states. Small enough that the
    /// CTA fits above the keyboard in landscape compact-height (~393pt tall),
    /// so even if focus returns to the search field the button remains
    /// reachable via a short scroll.
    var keyboardSafeMinHeight: CGFloat { 280 }
}

// MARK: - Accessibility

#Preview("Idle — Light") {
    NavigationStack {
        SearchView(viewModel: SearchViewModel(client: .preview))
    }
}

#Preview("Idle — Dark") {
    NavigationStack {
        SearchView(viewModel: SearchViewModel(client: .preview))
    }
    .preferredColorScheme(.dark)
}
