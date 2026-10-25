import Foundation

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

struct ProviderKeyState: Identifiable, Equatable, Sendable {
    let provider: Provider
    let hasKey: Bool

    var id: String { provider.id }
}

enum ProviderFactory {
    enum ValidationFailure: Error, Equatable {
        case emptyName
        case invalidURL
        case emptyModel

        var message: String {
            switch self {
            case .emptyName:
                String(localized: "Enter a name for the assistant.", comment: "Custom provider validation: missing name")
            case .invalidURL:
                String(localized: "Enter an https:// base URL.", comment: "Custom provider validation: invalid base URL")
            case .emptyModel:
                String(localized: "Enter the model name this endpoint accepts.", comment: "Custom provider validation: missing model")
            }
        }
    }

    static func custom(name: String, baseURL: String, model: String) throws -> Provider {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else { throw ValidationFailure.emptyName }
        guard let normalizedURL = normalizedBaseURL(trimmedURL) else { throw ValidationFailure.invalidURL }
        guard trimmedModel.isEmpty == false else { throw ValidationFailure.emptyModel }
        return Provider(
            id: "custom-\(UUID().uuidString)",
            name: trimmedName,
            kind: .openAICompatible,
            baseURL: normalizedURL,
            model: trimmedModel
        )
    }

    /// Accepts a plain https base URL and drops trailing slashes and a pasted `/chat/completions`.
    private static func normalizedBaseURL(_ text: String) -> String? {
        guard var components = URLComponents(string: text),
              components.scheme == "https",
              components.host?.isEmpty == false,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil else { return nil }
        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        if path.hasSuffix("/chat/completions") {
            path.removeLast("/chat/completions".count)
            while path.hasSuffix("/") { path.removeLast() }
        }
        components.path = path
        return components.string
    }
}
