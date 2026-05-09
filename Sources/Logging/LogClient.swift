// LogClient.swift
// Function-style logging client. One closure per call site so the test factory
// can record events and the live factory can route to os.Logger.

import Foundation
import OSLog

struct LogClient: Sendable {
    var debug: @Sendable (_ event: String, _ payload: [String: String]) -> Void
    var info: @Sendable (_ event: String, _ payload: [String: String]) -> Void
    var warn: @Sendable (_ event: String, _ payload: [String: String]) -> Void
    var error: @Sendable (_ event: String, _ payload: [String: String]) -> Void
}

extension LogClient {
    /// Production wiring — routes through `os.Logger` with the ResortPass subsystem.
    static let live: LogClient = {
        let logger = Logger(subsystem: "com.resortpass.interview.ResortPass", category: "app")
        return LogClient(
            debug: { event, payload in logger.debug("\(event, privacy: .public) \(payload, privacy: .public)") },
            info:  { event, payload in logger.info("\(event, privacy: .public) \(payload, privacy: .public)") },
            warn:  { event, payload in logger.warning("\(event, privacy: .public) \(payload, privacy: .public)") },
            error: { event, payload in logger.error("\(event, privacy: .public) \(payload, privacy: .public)") }
        )
    }()

    /// Test wiring — silently discards every call.
    static let silent = LogClient(
        debug: { _, _ in },
        info:  { _, _ in },
        warn:  { _, _ in },
        error: { _, _ in }
    )
}
