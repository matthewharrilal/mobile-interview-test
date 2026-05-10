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
            // can't literally consume a SwiftUI `Animation`, so the duration
            // is centralized in `Theme.Animation.kfFadeDuration` to keep
            // every KFImage call site in lockstep with the rest of the
            // animation cadence. Tune both call sites by editing Theme.
            .fade(duration: Theme.Animation.kfFadeDuration)
            .cancelOnDisappear(true)
            .resizable()
    }
}
