import Foundation

/// Test-only ``URLProtocol`` that serves pre-registered responses.
///
/// Usage: register ``stub(url:response:body:deliveryDelay:)`` for the URLs the
/// test exercises, then install ``MockURLProtocol`` on a
/// ``URLSessionConfiguration.protocolClasses`` and build a ``URLSession`` with
/// it. ``HermesClientTests`` does exactly this in its `makeClient()` helper.
///
/// Supports an optional per-stub delivery delay so tests can exercise
/// cancellation reliably — ``URLSession.bytes(for:)`` only fires cancellation
/// observations while bytes are actually in flight, so without the delay a
/// stub that returns immediately races ahead of any `Task.cancel()`.
///
/// Not thread-safe on its own; tests that use it must run serialised (see
/// `@Suite(..., .serialized)` on ``HermesClientTests``) so the shared stub
/// registry does not leak between cases.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    struct Stub {
        let response: HTTPURLResponse
        let body: Data
        let deliveryDelay: TimeInterval
    }

    nonisolated(unsafe) static var stubs: [URL: Stub] = [:]

    /// Registers a canned response for `url`. Overwrites any previous stub
    /// for the same URL.
    static func stub(
        url: URL,
        response: HTTPURLResponse,
        body: Data,
        deliveryDelay: TimeInterval = 0
    ) {
        stubs[url] = Stub(response: response, body: body, deliveryDelay: deliveryDelay)
    }

    /// Clears all registered stubs. Call from a test's `init()` to get a
    /// clean slate per test case.
    static func reset() {
        stubs.removeAll()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let stub = Self.stubs[url] else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }

        client?.urlProtocol(self, didReceive: stub.response, cacheStoragePolicy: .notAllowed)

        if stub.deliveryDelay > 0 {
            // Deliver the body after a delay so tests have a real window to
            // observe cancellation. We use GCD instead of a Swift Task here
            // because URLProtocol is not Sendable-friendly.
            let body = stub.body
            let urlClient = client
            let urlProtocol = self
            DispatchQueue.global().asyncAfter(deadline: .now() + stub.deliveryDelay) {
                urlClient?.urlProtocol(urlProtocol, didLoad: body)
                urlClient?.urlProtocolDidFinishLoading(urlProtocol)
            }
        } else {
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
