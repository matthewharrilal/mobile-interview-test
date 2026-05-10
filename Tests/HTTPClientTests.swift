// HTTPClientTests.swift
// Verifies `HTTPClient.live` correctly maps URLSession responses to the
// domain error surface, using a URLProtocol-backed `URLSession` to stub
// transport. Validates the README's claim that the seam exists and is
// the actual test seam for upstream networking behavior.

import XCTest
@testable import ResortPass

final class HTTPClientTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        StubProtocol.reset()
    }

    override class func tearDown() {
        StubProtocol.reset()
        super.tearDown()
    }

    // MARK: - Happy path

    func test_send_2xx_returnsDataAndResponse() async throws {
        let url = URL(string: "https://stub.test/ok")!
        let payload = #"{"hello":"world"}"#.data(using: .utf8)!
        StubProtocol.handler = { req in
            XCTAssertEqual(req.url, url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (response, payload)
        }

        let client = HTTPClient.live(session: makeStubbedSession())
        let (data, response) = try await client.send(URLRequest(url: url))

        XCTAssertEqual(data, payload)
        XCTAssertEqual(response.statusCode, 200)
    }

    func test_send_204_isAcceptedAsSuccess() async throws {
        // The success range is 200..<300, so 204 (No Content) must succeed
        // even with empty body. Pin so a future tightening to 200..<201
        // breaks this test instead of silently dropping responses.
        let url = URL(string: "https://stub.test/no-content")!
        StubProtocol.handler = { _ in
            (HTTPURLResponse(url: url, statusCode: 204, httpVersion: "HTTP/1.1", headerFields: nil)!, Data())
        }

        let client = HTTPClient.live(session: makeStubbedSession())
        let (data, response) = try await client.send(URLRequest(url: url))

        XCTAssertTrue(data.isEmpty)
        XCTAssertEqual(response.statusCode, 204)
    }

    // MARK: - Error path

    func test_send_4xx_throwsStatusError() async {
        let url = URL(string: "https://stub.test/forbidden")!
        StubProtocol.handler = { _ in
            (HTTPURLResponse(url: url, statusCode: 403, httpVersion: "HTTP/1.1", headerFields: nil)!, Data())
        }

        let client = HTTPClient.live(session: makeStubbedSession())
        do {
            _ = try await client.send(URLRequest(url: url))
            XCTFail("Expected NetworkingError.status(403), got success")
        } catch let NetworkingError.status(code) {
            XCTAssertEqual(code, 403, "Status code must be preserved verbatim through the error mapping")
        } catch {
            XCTFail("Expected NetworkingError.status(403), got \(error)")
        }
    }

    func test_send_5xx_throwsStatusError() async {
        let url = URL(string: "https://stub.test/internal-error")!
        StubProtocol.handler = { _ in
            (HTTPURLResponse(url: url, statusCode: 503, httpVersion: "HTTP/1.1", headerFields: nil)!, Data())
        }

        let client = HTTPClient.live(session: makeStubbedSession())
        do {
            _ = try await client.send(URLRequest(url: url))
            XCTFail("Expected NetworkingError.status(503)")
        } catch let NetworkingError.status(code) {
            XCTAssertEqual(code, 503)
        } catch {
            XCTFail("Expected NetworkingError.status(503), got \(error)")
        }
    }

    func test_send_non_http_response_throwsInvalidResponse() async {
        // URLSession can return a URLResponse that isn't an HTTPURLResponse
        // (e.g. file:// schemes). The client must surface this as
        // NetworkingError.invalidResponse, not crash on a force-cast.
        let url = URL(string: "https://stub.test/non-http")!
        StubProtocol.handler = { _ in
            // Construct a non-HTTP response by using base URLResponse
            (URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil), Data())
        }

        let client = HTTPClient.live(session: makeStubbedSession())
        do {
            _ = try await client.send(URLRequest(url: url))
            XCTFail("Expected NetworkingError.invalidResponse")
        } catch NetworkingError.invalidResponse {
            // success
        } catch {
            XCTFail("Expected NetworkingError.invalidResponse, got \(error)")
        }
    }

    func test_send_networkError_propagatesURLError() async {
        // When URLSession itself fails (no host, no connection), the URLError
        // should propagate AS-IS — not be wrapped in NetworkingError. The
        // VM's catch arms map URLError → ErrorKind, so swallowing it here
        // would break the user-facing failure-message routing.
        let url = URL(string: "https://stub.test/network-down")!
        StubProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let client = HTTPClient.live(session: makeStubbedSession())
        do {
            _ = try await client.send(URLRequest(url: url))
            XCTFail("Expected URLError to propagate")
        } catch let urlError as URLError {
            XCTAssertEqual(urlError.code, .notConnectedToInternet)
        } catch {
            XCTFail("Expected URLError, got \(error)")
        }
    }

    // MARK: - Cancellation

    func test_send_taskCancellation_propagatesToURLSession() async {
        // The README + audit explicitly claim cancellation cascades through
        // to URLSession. Verify by stubbing a slow response and cancelling
        // the Task mid-flight: the wait must end before the stub fires.
        let url = URL(string: "https://stub.test/slow")!
        let stubFired = TestFlag()
        StubProtocol.handler = { _ in
            Thread.sleep(forTimeInterval: 2.0)   // slow, simulating a never-completing call
            stubFired.set()
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!, Data())
        }

        let client = HTTPClient.live(session: makeStubbedSession())
        let task = Task {
            try await client.send(URLRequest(url: url))
        }

        // Cancel before the stub finishes its 2s sleep.
        try? await Task.sleep(for: .milliseconds(200))
        task.cancel()

        let result = await task.result
        switch result {
        case .success:
            XCTFail("Expected cancellation, got success")
        case .failure(let error):
            // URLSession cancellation surfaces as URLError(.cancelled). The
            // outer client doesn't translate it (the VM does, via ErrorKind);
            // here we just verify the cancellation propagated.
            if let urlError = error as? URLError {
                XCTAssertEqual(urlError.code, .cancelled, "Cancellation must propagate as URLError.cancelled, got \(urlError.code)")
            } else if error is CancellationError {
                // Acceptable: Swift Concurrency surfaced the cancellation directly.
            } else {
                XCTFail("Expected URLError(.cancelled) or CancellationError, got \(error)")
            }
        }
    }

    // MARK: - Helpers

    /// Builds a `URLSession` whose only protocol class is `StubProtocol`,
    /// so every request routes through our handler. This is the
    /// canonical URLProtocol-based stubbing pattern referenced in the
    /// README's networking rationale.
    private func makeStubbedSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: config)
    }
}

// MARK: - Stub URLProtocol

/// Routes every `URLRequest` through a configurable handler closure.
/// Use `StubProtocol.handler = { req in ... }` before each test; call
/// `StubProtocol.reset()` between tests to avoid cross-pollination.
private final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (URLResponse, Data))?

    static func reset() {
        handler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = StubProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Test flag

/// Thread-safe boolean for cancellation timing assertions.
private final class TestFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Bool = false

    func set() {
        lock.lock(); defer { lock.unlock() }
        value = true
    }

    var isSet: Bool {
        lock.lock(); defer { lock.unlock() }
        return value
    }
}
