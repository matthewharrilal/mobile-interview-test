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
        actor Recorder {
            var events: [(severity: String, name: String, payload: [String: String])] = []
            func record(_ severity: String, _ name: String, _ payload: [String: String]) {
                events.append((severity, name, payload))
            }
        }
        let recorder = Recorder()
        let log = LogClient(
            debug: { name, payload in Task { await recorder.record("debug", name, payload) } },
            info:  { name, payload in Task { await recorder.record("info",  name, payload) } },
            error: { name, payload in Task { await recorder.record("error", name, payload) } }
        )

        log.debug("search.initiated", ["query": "newport"])
        log.info("search.completed", ["count": "3"])
        log.error("search.failed", ["error": "boom"])

        // Allow the dispatched recording Tasks to land.
        let exp = expectation(description: "events recorded")
        Task {
            // Give other tasks a moment to run.
            try? await Task.sleep(for: .milliseconds(50))
            let events = await recorder.events
            XCTAssertEqual(events.count, 3)
            XCTAssertEqual(events.map(\.severity), ["debug", "info", "error"])
            XCTAssertEqual(events.map(\.name), ["search.initiated", "search.completed", "search.failed"])
            XCTAssertEqual(events[1].payload, ["count": "3"])
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func test_logEventOverload_dispatchesWithRawValue() {
        actor Capture {
            var lastName: String = ""
            func set(_ name: String) { lastName = name }
        }
        let capture = Capture()
        let log = LogClient(
            debug: { name, _ in Task { await capture.set(name) } },
            info:  { name, _ in Task { await capture.set(name) } },
            error: { name, _ in Task { await capture.set(name) } }
        )

        log.info(.hotelsCompleted)

        let exp = expectation(description: "captured")
        Task {
            try? await Task.sleep(for: .milliseconds(50))
            let value = await capture.lastName
            XCTAssertEqual(value, "hotels.completed")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
}
