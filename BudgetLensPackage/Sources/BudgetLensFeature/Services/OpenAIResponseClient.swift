import Foundation

protocol LLMResponding: Sendable {
    func respond(key: String, instructions: String, messages: [ProviderMessage]) async throws -> String
}

struct ProviderMessage: Encodable, Sendable {
    let role: String
    let content: String
}

enum ProviderFailure: Error {
    case invalidKey
    case quotaOrRateLimit
    case rejectedRequest
    case connection
    case unusableReply
    case serviceUnavailable
}

struct OpenAIResponseClient: LLMResponding {
    let provider: Provider
    let session: URLSession

    init(provider: Provider, session: URLSession = URLSession(configuration: .ephemeral)) {
        self.provider = provider
        self.session = session
    }

    func respond(key: String, instructions: String, messages: [ProviderMessage]) async throws -> String {
        guard let base = provider.baseURL, let url = URL(string: "\(base)/v1/responses") else {
            throw ProviderFailure.serviceUnavailable
        }
        let body = ResponseRequest(model: provider.model, instructions: instructions, input: messages, store: false)
        let data = try await session.postJSON(to: url, headers: ["Authorization": "Bearer \(key)"], body: body)
        return try Self.parseReply(data)
    }

    static func parseReply(_ data: Data) throws -> String {
        guard let reply = try? JSONDecoder().decode(ResponseBody.self, from: data),
              reply.status == "completed" else {
            throw ProviderFailure.unusableReply
        }
        let text = reply.output
            .filter { $0.type == "message" && $0.role == "assistant" }
            .flatMap(\.content)
            .filter { $0.type == "output_text" }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { throw ProviderFailure.unusableReply }
        return text
    }
}

private struct ResponseRequest: Encodable {
    let model: String
    let instructions: String
    let input: [ProviderMessage]
    let store: Bool
}

private struct ResponseBody: Decodable {
    let status: String
    let output: [ResponseOutput]
}

private struct ResponseOutput: Decodable {
    let type: String
    let role: String?
    let content: [ResponseContent]

    enum CodingKeys: String, CodingKey { case type, role, content }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        content = try container.decodeIfPresent([ResponseContent].self, forKey: .content) ?? []
    }
}

private struct ResponseContent: Decodable {
    let type: String
    let text: String?
}
