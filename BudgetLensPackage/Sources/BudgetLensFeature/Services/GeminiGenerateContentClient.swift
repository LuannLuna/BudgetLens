import Foundation

struct GeminiGenerateContentClient: LLMResponding {
    let provider: Provider
    let session: URLSession

    init(provider: Provider, session: URLSession = URLSession(configuration: .ephemeral)) {
        self.provider = provider
        self.session = session
    }

    func respond(key: String, instructions: String, messages: [ProviderMessage]) async throws -> String {
        guard let base = provider.baseURL,
              let url = URL(string: "\(base)/v1beta/models/\(provider.model):generateContent") else {
            throw ProviderFailure.serviceUnavailable
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = GeminiRequest(
            systemInstruction: GeminiContent(role: nil, parts: [GeminiPart(text: instructions)]),
            contents: messages.map { message in
                GeminiContent(
                    role: message.role == "user" ? "user" : "model",
                    parts: [GeminiPart(text: message.content)]
                )
            }
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, http) = try await session.providerData(for: request)
        if let failure = ProviderStatusMapping.classify(status: http.statusCode, body: data) { throw failure }
        return try Self.parseReply(data)
    }

    static func parseReply(_ data: Data) throws -> String {
        guard let reply = try? JSONDecoder().decode(GeminiResponse.self, from: data) else {
            throw ProviderFailure.unusableReply
        }
        let text = reply.candidates
            .flatMap(\.content.parts)
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { throw ProviderFailure.unusableReply }
        return text
    }
}

private struct GeminiRequest: Encodable {
    let systemInstruction: GeminiContent
    let contents: [GeminiContent]

    enum CodingKeys: String, CodingKey {
        case systemInstruction = "system_instruction"
        case contents
    }
}

private struct GeminiContent: Encodable {
    let role: String?
    let parts: [GeminiPart]

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encode(parts, forKey: .parts)
    }

    private enum CodingKeys: String, CodingKey { case role, parts }
}

private struct GeminiPart: Encodable {
    let text: String
}

private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Decodable {
    let content: GeminiResponseContent
}

private struct GeminiResponseContent: Decodable {
    let parts: [GeminiResponsePart]
}

private struct GeminiResponsePart: Decodable {
    let text: String?
}
