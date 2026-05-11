// LogEvent.swift
// Typed log event names. Replaces raw strings like "search.initiated" so
// a typo can't silently break log indexing.

import Foundation

enum LogEvent: String, Sendable {
    case searchInitiated = "search.initiated"
    case searchCompleted = "search.completed"
    case searchFailed = "search.failed"
    case hotelsInitiated = "hotels.initiated"
    case hotelsCompleted = "hotels.completed"
    case hotelsFailed = "hotels.failed"
}

extension LogClient {
    func debug(_ event: LogEvent, _ payload: [String: String] = [:]) {
        debug(event.rawValue, payload)
    }
    func info(_ event: LogEvent, _ payload: [String: String] = [:]) {
        info(event.rawValue, payload)
    }
    func error(_ event: LogEvent, _ payload: [String: String] = [:]) {
        error(event.rawValue, payload)
    }
}
