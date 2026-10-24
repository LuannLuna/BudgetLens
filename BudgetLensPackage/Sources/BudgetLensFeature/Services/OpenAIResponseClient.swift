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
    case connection
    case unusableReply
    case serviceUnavailable
}

struct OpenAIResponseClient: LLMResponding {
    let session: URLSession

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    func respond(key: String, instructions: String, messages: [ProviderMessage]) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw ProviderFailure.serviceUnavailable
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ResponseRequest(model: "gpt-4.1-mini", instructions: instructions, input: messages, store: false)
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw ProviderFailure.connection
        }
        guard let http = response as? HTTPURLResponse else { throw ProviderFailure.serviceUnavailable }
        if http.statusCode == 401 || http.statusCode == 403 { throw ProviderFailure.invalidKey }
        guard (200..<300).contains(http.statusCode) else { throw ProviderFailure.serviceUnavailable }
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
