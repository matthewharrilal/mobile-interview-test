// Place+PreviewFixtures.swift
// Preview/test fixture data for `Place`. Lives in the domain layer rather
// than inside SearchClient.swift so the networking module isn't carrying
// fixture concerns.

import Foundation

extension Place {
    /// Returns up to three sample places matching the query (case-insensitive
    /// substring against the place name). An empty query returns all three.
    /// Used by `SearchClient.preview` and by the `failingThenRecovers`
    /// variant after the first call.
    static func fixturesMatching(_ query: String) -> [Place] {
        let all = [
            Place(placeID: 236, objectID: "Newport Beach, California", name: "Newport Beach, California", type: "city", cityName: "Newport Beach", stateCode: "CA", countryCode: "US", latitude: 33.6189, longitude: -117.9298),
            Place(placeID: 1265, objectID: "Newport, Rhode Island", name: "Newport, Rhode Island", type: "city", cityName: "Newport", stateCode: "RI", countryCode: "US", latitude: 41.4901, longitude: -71.3128),
            Place(placeID: 14, objectID: "Jamaica", name: "Jamaica", type: "country", cityName: "", stateCode: "", countryCode: "JM", latitude: 18.1096, longitude: -77.2975)
        ]
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}
