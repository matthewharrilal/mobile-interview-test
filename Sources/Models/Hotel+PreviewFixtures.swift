// Hotel+PreviewFixtures.swift
// Preview/test fixture data for `Hotel`. Lives in the domain layer rather
// than inside HotelsClient.swift.

import Foundation

extension Hotel {
    /// Three sample hotels used by `HotelsClient.preview`, the
    /// `failingThenRecovers` variant, and SwiftUI Previews.
    static let previewFixtures: [Hotel] = [
        Hotel(
            id: 1, name: "TWA Hotel",
            imageURL: URL(string: "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800"),
            rating: 4.1, reviewCount: 164, distanceMiles: 8, distanceText: "8 mi",
            productName: "Pool Pass 9pm-10:45pm", primaryVibe: "Trendy", cheapestPrice: 50
        ),
        Hotel(
            id: 2, name: "Hyatt Regency JFK",
            imageURL: URL(string: "https://images.unsplash.com/photo-1582719508461-905c673771fd?w=800"),
            rating: 4.3, reviewCount: 89, distanceMiles: 3, distanceText: "3 mi",
            productName: "Day Pass 10am-6pm", primaryVibe: "Modern", cheapestPrice: 75
        ),
        Hotel(
            id: 3, name: "The Ritz-Carlton, Half Moon Bay",
            imageURL: URL(string: "https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800"),
            rating: 4.8, reviewCount: 421, distanceMiles: 5, distanceText: "5 mi",
            productName: "Pool & Spa Day Pass", primaryVibe: "Luxury", cheapestPrice: 195
        )
    ]
}
