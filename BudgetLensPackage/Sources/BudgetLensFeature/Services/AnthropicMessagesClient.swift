import Foundation

struct AnthropicMessagesClient: LLMResponding {
    let provider: Provider
    let session: URLSession

    init(provider: Provider, session: URLSession = URLSession(configuration: .ephemeral)) {
        self.provider = provider
        self.session = session
    }

    func respond(key: String, instructions: String, messages: [ProviderMessage]) async throws -> String {
        guard let base = provider.baseURL, let url = URL(string: "\(base)/v1/messages") else {
            throw ProviderFailure.serviceUnavailable
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = AnthropicRequest(model: provider.model, maxTokens: 1024, system: instructions, messages: messages)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, http) = try await session.providerData(for: request)
        if let failure = ProviderStatusMapping.classify(status: http.statusCode, body: data) { throw failure }
        return try Self.parseReply(data)
    }

    static func parseReply(_ data: Data) throws -> String {
        guard let reply = try? JSONDecoder().decode(AnthropicResponse.self, from: data) else {
            throw ProviderFailure.unusableReply
        }
        let text = reply.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { throw ProviderFailure.unusableReply }
        return text
    }
}

private struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [ProviderMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }
}

private struct AnthropicResponse: Decodable {
    let content: [AnthropicContent]
}

private struct AnthropicContent: Decodable {
    let type: String
    let text: String?
}
