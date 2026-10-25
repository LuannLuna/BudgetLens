import Foundation

protocol LLMResponding: Sendable {
    func respond(key: String, instructions: String, messages: [ProviderMessage]) async throws -> String
}

struct ProviderMessage: Encodable, Sendable {
    let role: String
    let content: String
}
