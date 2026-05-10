// Place.swift
// Cross-feature domain type — a searchable place returned by the autocomplete API.
// Coordinates may be nil for some entries. Note: the API's `id` (Int) is NOT
// unique across aliases (e.g. Newport Beach and Newport Coast both have id=236);
// `objectID` (String) is the stable unique key, so Identifiable.id maps to it.

import Foundation

struct Place: Equatable, Sendable, Hashable, Identifiable, Codable {
    let placeID: Int
    let objectID: String
    let name: String
    let type: String
    let cityName: String
    let stateCode: String
    let countryCode: String
    let latitude: Double?
    let longitude: Double?

    var id: String { objectID }

    enum CodingKeys: String, CodingKey {
        case placeID = "id"
        case objectID
        case name
        case type
        case cityName = "city_name"
        case stateCode = "state_code"
        case countryCode = "country_code"
        case latitude
        case longitude
    }

    /// Whether this place can navigate to the hotels screen.
    /// Some real-world entries (e.g. "Brooklyn, Florida") have null coordinates;
    /// without lat/lng the algolia_hotels_v7 endpoint cannot return meaningful results.
    var hasUsableCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    /// SF Symbol name for the place type — drives the leading icon in search rows.
    /// Keeps the icon vocabulary consistent and centralised so renames stay local.
    var iconSymbolName: String {
        switch type {
        case "country":
            return "globe.americas"
        case "alias":
            return "mappin.and.ellipse"
        case "city":
            return "building.2"
        default:
            return "mappin"
        }
    }

    /// Short type label shown alongside place name in search rows.
    var typeBadge: String {
        switch type {
        case "country": return "Country"
        case "alias":   return "Nearby"
        case "city":    return "City"
        default:        return ""
        }
    }

    var isAlias: Bool { type == "alias" }

    /// Displayed under the place name in the search row.
    /// Examples: "Jersey City · NJ, US", "Jamaica · Country", "Newport · RI, US".
    var displayRegion: String? {
        switch type {
        case "country":
            return countryCode.isEmpty ? "Country" : "\(countryCode) · Country"
        default:
            let cityPart = cityName.isEmpty ? name : cityName
            let stateAndCountry = [stateCode, countryCode].filter { !$0.isEmpty }.joined(separator: ", ")
            let combined = stateAndCountry.isEmpty ? cityPart : "\(cityPart) · \(stateAndCountry)"
            return combined.isEmpty ? nil : combined
        }
    }
}
