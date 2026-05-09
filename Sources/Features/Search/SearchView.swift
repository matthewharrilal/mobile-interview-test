// SearchView.swift
// SwiftUI view for the Search screen — search bar at top, content body per Status.

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
                .font(Theme.Typography.titleM)
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
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.l))
    }

    func loadedState(_ places: [Place]) -> some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.s) {
                ForEach(places) { place in
                    Button { viewModel.send(.placeSelected(place)) } label: {
                        placeRow(place)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text(String(format: Strings.Accessibility.placeRowHintFormat, place.name)))
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
        }
    }

    func placeRow(_ place: Place) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(place.name)
                    .font(Theme.Typography.titleS)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .multilineTextAlignment(.leading)
                if let region = place.displayRegion {
                    Label(region, systemImage: Theme.Icon.mapPin)
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .labelStyle(.titleAndIcon)
                }
            }
            Spacer()
            Image(systemName: Theme.Icon.chevronRight)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Color.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.l))
        .shadow(
            color: Theme.Elevation.card.color,
            radius: Theme.Elevation.card.radius,
            x: Theme.Elevation.card.x,
            y: Theme.Elevation.card.y
        )
    }

    var emptyState: some View {
        ContentUnavailableView(
            Strings.Search.emptyHeadline,
            systemImage: Theme.Icon.search,
            description: Text(String(format: Strings.Search.emptyDescriptionFormat, viewModel.state.query))
        )
    }

    func failedState(_ message: String) -> some View {
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
    }
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
