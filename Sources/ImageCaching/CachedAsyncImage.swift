// CachedAsyncImage.swift
// SwiftUI wrapper around Kingfisher's KFImage. Applies the editorial color
// grade to every loaded image so mixed user-supplied photography unifies
// into a single visual voice.

import SwiftUI
import Kingfisher

struct CachedAsyncImage: View {
    let url: URL?

    var body: some View {
        KFImage(url)
            .setProcessor(EditorialGradeProcessor())
            .placeholder { Color.gray.opacity(0.15) }
            // Kingfisher's `.fade(duration:)` is a CATransition wrapper and
            // can't literally consume a SwiftUI `Animation`, but the duration
            // is held to `Theme.Animation.quickFade`'s 0.2s envelope so image
            // reveals match the rest of the cadence. Tune both together.
            .fade(duration: 0.2)
            .cancelOnDisappear(true)
            .resizable()
    }
}
