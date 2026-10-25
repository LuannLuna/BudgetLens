import Foundation
import os
import Testing
@testable import BudgetLensFeature

/// Serves canned replies and records what was sent, keyed by host so tests can run in parallel.
final class StubURLProtocol: URLProtocol {
    struct Reply: Sendable {
        var status = 200
        var body = Data()
        var error: URLError?
    }

    struct Sent: Sendable {
        let request: URLRequest
        let body: Data
    }

    private static let replies = OSAllocatedUnfairLock(initialState: [String: Reply]())
    private static let sentRequests = OSAllocatedUnfairLock(initialState: [String: Sent]())

    static func stub(host: String, _ reply: Reply) {
        replies.withLock { $0[host] = reply }
    }

    static func sent(to host: String) -> Sent? {
        sentRequests.withLock { $0[host] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url, let host = url.host else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let sent = Sent(request: request, body: Self.body(of: request))
        Self.sentRequests.withLock { $0[host] = sent }
        let reply = Self.replies.withLock { $0[host] } ?? Reply(status: 404)
        if let error = reply.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: nil, headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    /// URLSession hands the body over as a stream, so it has to be read back to be inspected.
    private static func body(of request: URLRequest) -> Data {
        guard let stream = request.httpBodyStream else { return request.httpBody ?? Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

struct ProviderRequestTests {
    private let messages = [
        ProviderMessage(role: "user", content: "Context"),
        ProviderMessage(role: "assistant", content: "Earlier"),
        ProviderMessage(role: "user", content: "Question?")
    ]

    @Test func openAISendsBearerKeyToTheResponsesEndpoint() async throws {
        let host = uniqueHost("openai")
        let reply = #"{"status":"completed","output":[{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Hello"}]}]}"#
        StubURLProtocol.stub(host: host, .init(body: Data(reply.utf8)))
        let client = OpenAIResponseClient(provider: provider(.openAIResponses, host: host), session: stubbedSession())

        let text = try await client.respond(key: "key-1", instructions: "Be kind", messages: messages)

        #expect(text == "Hello")
        let sent = try #require(StubURLProtocol.sent(to: host))
        #expect(sent.request.httpMethod == "POST")
        #expect(sent.request.url?.path == "/v1/responses")
        #expect(sent.request.value(forHTTPHeaderField: "Authorization") == "Bearer key-1")
        #expect(sent.request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try jsonObject(sent.body)
        #expect(body["model"] as? String == "model-x")
        #expect(body["instructions"] as? String == "Be kind")
        #expect(body["store"] as? Bool == false)
        #expect((body["input"] as? [[String: Any]])?.count == 3)
    }

    @Test func anthropicSendsKeyVersionAndSystemPrompt() async throws {
        let host = uniqueHost("anthropic")
        StubURLProtocol.stub(host: host, .init(body: Data(#"{"content":[{"type":"text","text":"Hello"}]}"#.utf8)))
        let client = AnthropicMessagesClient(provider: provider(.anthropicMessages, host: host), session: stubbedSession())

        let text = try await client.respond(key: "key-1", instructions: "Be kind", messages: messages)

        #expect(text == "Hello")
        let sent = try #require(StubURLProtocol.sent(to: host))
        #expect(sent.request.url?.path == "/v1/messages")
        #expect(sent.request.value(forHTTPHeaderField: "x-api-key") == "key-1")
        #expect(sent.request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(sent.request.value(forHTTPHeaderField: "Authorization") == nil)
        let body = try jsonObject(sent.body)
        #expect(body["system"] as? String == "Be kind")
        #expect(body["max_tokens"] as? Int == 1024)
        #expect((body["messages"] as? [[String: Any]])?.count == 3)
    }

    @Test func geminiSendsKeyHeaderAndMapsAssistantToModel() async throws {
        let host = uniqueHost("gemini")
        StubURLProtocol.stub(host: host, .init(body: Data(#"{"candidates":[{"content":{"parts":[{"text":"Hello"}]}}]}"#.utf8)))
        let client = GeminiGenerateContentClient(provider: provider(.gemini, host: host), session: stubbedSession())

        let text = try await client.respond(key: "key-1", instructions: "Be kind", messages: messages)

        #expect(text == "Hello")
        let sent = try #require(StubURLProtocol.sent(to: host))
        #expect(sent.request.url?.path == "/v1beta/models/model-x:generateContent")
        #expect(sent.request.value(forHTTPHeaderField: "x-goog-api-key") == "key-1")
        #expect(sent.request.url?.query == nil)
        let body = try jsonObject(sent.body)
        let roles = (body["contents"] as? [[String: Any]])?.compactMap { $0["role"] as? String }
        #expect(roles == ["user", "model", "user"])
        #expect(body["system_instruction"] != nil)
    }

    @Test func openAICompatibleSendsTheSystemPromptFirst() async throws {
        let host = uniqueHost("compatible")
        StubURLProtocol.stub(host: host, .init(body: Data(#"{"choices":[{"message":{"content":"Hello"}}]}"#.utf8)))
        let client = OpenAICompatibleChatClient(provider: provider(.openAICompatible, host: host), session: stubbedSession())

        let text = try await client.respond(key: "key-1", instructions: "Be kind", messages: messages)

        #expect(text == "Hello")
        let sent = try #require(StubURLProtocol.sent(to: host))
        #expect(sent.request.url?.path == "/chat/completions")
        #expect(sent.request.value(forHTTPHeaderField: "Authorization") == "Bearer key-1")
        let sentMessages = try #require(try jsonObject(sent.body)["messages"] as? [[String: Any]])
        #expect(sentMessages.count == 4)
        #expect(sentMessages.first?["role"] as? String == "system")
        #expect(sentMessages.first?["content"] as? String == "Be kind")
    }

    @Test(arguments: [
        (401, ProviderFailure.invalidKey),
        (429, ProviderFailure.quotaOrRateLimit),
        (404, ProviderFailure.rejectedRequest),
        (503, ProviderFailure.serviceUnavailable)
    ])
    func httpFailuresBecomeProviderFailures(status: Int, expected: ProviderFailure) async {
        let host = uniqueHost("failure")
        StubURLProtocol.stub(host: host, .init(status: status))
        let client = OpenAICompatibleChatClient(provider: provider(.openAICompatible, host: host), session: stubbedSession())

        await #expect(throws: expected) {
            try await client.respond(key: "key-1", instructions: "Be kind", messages: messages)
        }
    }

    @Test func transportErrorsBecomeConnectionFailures() async {
        let host = uniqueHost("offline")
        StubURLProtocol.stub(host: host, .init(error: URLError(.notConnectedToInternet)))
        let client = OpenAICompatibleChatClient(provider: provider(.openAICompatible, host: host), session: stubbedSession())

        await #expect(throws: ProviderFailure.connection) {
            try await client.respond(key: "key-1", instructions: "Be kind", messages: messages)
        }
    }

    private func uniqueHost(_ label: String) -> String {
        "\(label)-\(UUID().uuidString.lowercased()).test"
    }

    private func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func provider(_ kind: Provider.Kind, host: String) -> Provider {
        Provider(id: "stub-\(host)", name: "Stub", kind: kind, baseURL: "https://\(host)", model: "model-x")
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
