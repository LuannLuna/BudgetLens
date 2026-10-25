import Foundation

enum ProviderFactory {
    enum ValidationFailure: Error, Equatable, Sendable {
        case emptyName
        case invalidURL
        case emptyModel
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
