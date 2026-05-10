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
            .fade(duration: 0.2)
            .cancelOnDisappear(true)
            .resizable()
    }
}
