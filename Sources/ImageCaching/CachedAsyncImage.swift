// CachedAsyncImage.swift
// SwiftUI wrapper around Kingfisher's KFImage. Single integration point so a
// future swap to NSCache or another library only changes this file.

import SwiftUI
import Kingfisher

struct CachedAsyncImage: View {
    let url: URL?

    var body: some View {
        KFImage(url)
            .placeholder { Color.gray.opacity(0.15) }
            .fade(duration: 0.2)
            .cancelOnDisappear(true)
            .resizable()
    }
}
