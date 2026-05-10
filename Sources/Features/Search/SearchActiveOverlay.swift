// SearchActiveOverlay.swift
// Architect-scaffolded surface for Transition 1 (search-pill blur-crossfade).
// Renders a search bar pill + autocomplete content but carries NO blur, dim,
// crossfade, or focus-delay logic — Worker A fills those in.
//
// Contract (do not change without coordinating via SendMessage):
//   viewModel: the host's SearchViewModel — Worker A reads/writes its state but
//              does not own its lifetime.
//   ns:        the host's matched-geometry namespace. Worker A wires
//              `matchedGeometryEffect(id: "searchPill", in: ns)` onto the pill
//              so it morphs from the host's floating pill bar.
//   onDismiss: called when the user taps outside the pill or the back chevron.
//              Worker A is responsible for wrapping the dismissal in
//              `withAnimation(.easeInOut(duration: 0.2))`.

import SwiftUI

struct SearchActiveOverlay: View {
    @Bindable var viewModel: SearchViewModel
    let ns: Namespace.ID
    var onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            // Worker A: replace this opaque background with a layered
            // blur+dim of the explore content underneath. For the scaffold
            // we use the page background so the surface reads as a normal
            // sheet and the build stays sane.
            Theme.Color.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                searchBar
                Divider()
                    .background(Theme.Color.border)
                content
            }
        }
    }
}

// MARK: - Search bar pill

private extension SearchActiveOverlay {
    /// Worker A: attach `matchedGeometryEffect(id: "searchPill", in: ns)` to
    /// the pill container so the host's floating pill morphs into this one.
    /// The keyboard appears as a separate event ~220ms after the surface
    /// lands — wire that via `Task.sleep(for: .milliseconds(220))` and
    /// `@FocusState`.
    var searchBar: some View {
        HStack(spacing: Theme.Spacing.s) {
            Button(action: onDismiss) {
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
                        // Worker A / polish phase: bubble selection up via a
                        // callback so the host can replace the nav path.
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
