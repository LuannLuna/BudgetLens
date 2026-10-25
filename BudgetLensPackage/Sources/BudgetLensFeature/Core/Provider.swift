import Foundation

/// One selectable assistant. It is plain configuration, so Core owns it and every layer can read it.
struct Provider: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case openAIResponses
        case anthropicMessages
        case gemini
        case openAICompatible
    }

    let id: String
    let name: String
    let kind: Kind
    let baseURL: String?
    let model: String

    var isBuiltIn: Bool {
        id.hasPrefix("custom-") == false
    }

    static let openAI = Provider(
        id: "openai",
        name: "OpenAI",
        kind: .openAIResponses,
        baseURL: "https://api.openai.com",
        model: "gpt-4.1-mini"
    )

    static let anthropic = Provider(
        id: "anthropic",
        name: "Anthropic",
        kind: .anthropicMessages,
        baseURL: "https://api.anthropic.com",
        model: "claude-haiku-5-5"
    )

    static let gemini = Provider(
        id: "gemini",
        name: "Gemini",
        kind: .gemini,
        baseURL: "https://generativelanguage.googleapis.com",
        model: "gemini-3.8-flash"
    )

    static let deepSeek = Provider(
        id: "deepseek",
        name: "DeepSeek",
        kind: .openAICompatible,
        baseURL: "https://api.deepseek.com",
        model: "deepseek-flash"
    )

    static let catalog: [Provider] = [.openAI, .anthropic, .gemini, .deepSeek]
}
