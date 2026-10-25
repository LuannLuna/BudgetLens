import Foundation

struct OpenAICompatibleChatClient: LLMResponding {
    let provider: Provider
    let session: URLSession

    init(provider: Provider, session: URLSession = URLSession(configuration: .ephemeral)) {
        self.provider = provider
        self.session = session
    }

    func respond(key: String, instructions: String, messages: [ProviderMessage]) async throws -> String {
        guard let base = provider.baseURL, let url = URL(string: "\(base)/chat/completions") else {
            throw ProviderFailure.serviceUnavailable
        }
        let chatMessages = [ProviderMessage(role: "system", content: instructions)] + messages
        let body = ChatCompletionsRequest(model: provider.model, messages: chatMessages)
        let data = try await session.postJSON(to: url, headers: ["Authorization": "Bearer \(key)"], body: body)
        return try Self.parseReply(data)
    }

    static func parseReply(_ data: Data) throws -> String {
        guard let reply = try? JSONDecoder().decode(ChatCompletionsResponse.self, from: data) else {
            throw ProviderFailure.unusableReply
        }
        let text = reply.choices
            .compactMap { $0.message.content }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { throw ProviderFailure.unusableReply }
        return text
    }
}

private struct ChatCompletionsRequest: Encodable {
    let model: String
    let messages: [ProviderMessage]
}

private struct ChatCompletionsResponse: Decodable {
    let choices: [ChatChoice]
}

private struct ChatChoice: Decodable {
    let message: ChatChoiceMessage
}

private struct ChatChoiceMessage: Decodable {
    let content: String?
}
