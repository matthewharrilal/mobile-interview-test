// LogClientTests.swift
// Smoke coverage for LogClient — the .silent factory discards, custom
// factories capture, and the LogEvent overload dispatches with the right
// raw value.

import XCTest
@testable import ResortPass

final class LogClientTests: XCTestCase {

    func test_silent_discardsAllCalls() {
        let log = LogClient.silent
        // None of these should throw, crash, or do anything observable.
        log.debug("x", [:])
        log.info("y", ["a": "b"])
        log.error("z", ["err": "bang"])
    }

    func test_customFactory_capturesEventNameAndPayload() {
        // Lock-backed recorder so the three log calls below append in
        // their invocation order regardless of how the closures are
        // dispatched. (Earlier version used `Task { ... }` inside the
        // closures and was order-flaky.)
        let recorder = SyncRecorder()
        let log = LogClient(
            debug: { name, payload in recorder.record("debug", name, payload) },
            info:  { name, payload in recorder.record("info",  name, payload) },
            error: { name, payload in recorder.record("error", name, payload) }
        )

        log.debug("search.initiated", ["query": "newport"])
        log.info("search.completed", ["count": "3"])
        log.error("search.failed", ["error": "boom"])

        let events = recorder.events
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events.map(\.severity), ["debug", "info", "error"])
        XCTAssertEqual(events.map(\.name), ["search.initiated", "search.completed", "search.failed"])
        XCTAssertEqual(events[1].payload, ["count": "3"])
    }

    func test_logEventOverload_dispatchesWithRawValue() {
        let recorder = SyncRecorder()
        let log = LogClient(
            debug: { name, payload in recorder.record("debug", name, payload) },
            info:  { name, payload in recorder.record("info",  name, payload) },
            error: { name, payload in recorder.record("error", name, payload) }
        )

        log.info(.hotelsCompleted)

        XCTAssertEqual(recorder.events.count, 1)
        XCTAssertEqual(recorder.events.first?.severity, "info")
        XCTAssertEqual(recorder.events.first?.name, "hotels.completed")
    }
}

// MARK: - Helpers

private final class SyncRecorder: @unchecked Sendable {
    struct Event {
        let severity: String
        let name: String
        let payload: [String: String]
    }
    private let lock = NSLock()
    private var _events: [Event] = []

    func record(_ severity: String, _ name: String, _ payload: [String: String]) {
        lock.lock(); defer { lock.unlock() }
        _events.append(Event(severity: severity, name: name, payload: payload))
    }

    var events: [Event] {
        lock.lock(); defer { lock.unlock() }
        return _events
    }
}
