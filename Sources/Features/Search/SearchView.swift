// SearchView.swift
// SwiftUI view for the Search screen — search bar at top, content body per Status.

import SwiftUI

// MARK: - Body

struct SearchView: View {
    @Bindable var viewModel: SearchViewModel

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
                .background(Theme.Color.border)
            content
        }
        .background(Theme.Color.background)
        .navigationTitle("Pokédex")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subviews

private extension SearchView {
    var searchBar: some View {
        HStack(spacing: Theme.Spacing.s) {
            if case .loading = viewModel.state.status {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.Color.textTertiary)
            }
            TextField("Search cities, hotels…", text: Binding(
                get: { viewModel.state.query },
                set: { viewModel.send(.queryChanged($0)) }
            ))
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Color.textPrimary)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            if !viewModel.state.query.isEmpty {
                Button { viewModel.send(.clearTapped) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Color.textTertiary)
                }
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
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.Color.textTertiary)
            Text("Where are you headed?")
                .font(Theme.Typography.titleM)
                .foregroundStyle(Theme.Color.textPrimary)
            Text("Type a city, neighborhood, or hotel\nname to discover day passes.")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Color.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.l)
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
                    Label(region, systemImage: "mappin.circle.fill")
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .labelStyle(.titleAndIcon)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Color.textTertiary)
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
            "No places found",
            systemImage: "magnifyingglass",
            description: Text("We couldn't find anywhere matching “\(viewModel.state.query)”. Try another term.")
        )
    }

    func failedState(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn't search", systemImage: "exclamationmark.triangle")
                .foregroundStyle(Theme.Color.danger)
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") { viewModel.send(.retryTapped) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Color.accent)
        }
    }
}

// MARK: - Accessibility

// Accessibility labels and traits land on the next pass once
// the localised string keys are wired.

#Preview("Idle") {
    NavigationStack {
        SearchView(viewModel: SearchViewModel(client: .preview))
    }
}
