// APIEnvironment.swift
// Single source of truth for the API base URL across build configurations.

import Foundation

enum APIEnvironment {
    case staging

    var baseURL: URL {
        switch self {
        case .staging:
            return URL(string: "https://staging-app.resortpass.com")!
        }
    }
}
