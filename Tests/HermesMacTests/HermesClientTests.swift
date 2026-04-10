import Testing
import Foundation
@testable import HermesMac

@Suite("HermesClient")
struct HermesClientTests {

    @Test("listModels decodes a valid response")
    func listModelsSuccess() async throws {
        let (client, protocolClass) = makeClient()
        let url = URL(string: "http://test.local/v1/models")!
        protocolClass.stubs[url] = (
            Data("""
            {"object":"list","data":[{"id":"hermes-agent","object":"model","owned_by":"hermes"}]}
            """.utf8),
            HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )

        await client.setEndpoint(HermesEndpoint(
            baseURL: URL(string: "http://test.local/v1")!,
            apiKey: "secret"
        ))

        let models = try await client.listModels()
        #expect(models.count == 1)
        #expect(models[0].id == "hermes-agent")
    }

    @Test("listModels throws HermesError.notAuthenticated when no endpoint set")
    func notAuthenticated() async {
        let (client, _) = makeClient()
        await #expect(throws: HermesError.notAuthenticated) {
            try await client.listModels()
        }
    }

    @Test("listModels maps 401 to httpStatus error")
    func httpError() async {
        let (client, protocolClass) = makeClient()
        let url = URL(string: "http://test.local/v1/models")!
        protocolClass.stubs[url] = (
            Data(#"{"error":{"message":"Invalid API key"}}"#.utf8),
            HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
        )

        await client.setEndpoint(HermesEndpoint(
            baseURL: URL(string: "http://test.local/v1")!,
            apiKey: "wrong"
        ))

        do {
            _ = try await client.listModels()
            Issue.record("Expected error")
        } catch let error as HermesError {
            if case .httpStatus(let code, _) = error {
                #expect(code == 401)
            } else {
                Issue.record("Wrong error: \(error)")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    // MARK: - Helpers

    private func makeClient() -> (HermesClient, MockURLProtocol.Type) {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return (HermesClient(session: session), MockURLProtocol.self)
    }
}

// MARK: - MockURLProtocol

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var stubs: [URL: (Data, HTTPURLResponse)] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let (data, response) = Self.stubs[url] else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
