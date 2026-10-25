import Testing
@testable import BudgetLensFeature

struct ProviderFactoryTests {
    @Test func buildsCustomProviderFromTrimmedInput() throws {
        let provider = try ProviderFactory.custom(name: "  Local  ", baseURL: " https://example.com ", model: " m1 ")
        #expect(provider.name == "Local")
        #expect(provider.baseURL == "https://example.com")
        #expect(provider.model == "m1")
        #expect(provider.id.hasPrefix("custom-"))
        #expect(provider.kind == .openAICompatible)
        #expect(provider.isBuiltIn == false)
    }

    @Test(arguments: [
        ("", "https://example.com", "m1"),
        ("Local", "http://example.com", "m1"),
        ("Local", "https://example.com", " "),
        ("Local", "https://", "m1"),
        ("Local", "not a url", "m1"),
        ("Local", "https://user:secret@example.com", "m1"),
        ("Local", "https://example.com/v1?key=1", "m1")
    ])
    func rejectsInvalidDetails(_ name: String, _ baseURL: String, _ model: String) {
        #expect(throws: ProviderFactory.ValidationFailure.self) {
            _ = try ProviderFactory.custom(name: name, baseURL: baseURL, model: model)
        }
    }

    @Test(arguments: [
        ("https://api.example.com/v1/", "https://api.example.com/v1"),
        ("https://api.example.com/v1/chat/completions", "https://api.example.com/v1"),
        ("https://api.example.com/v1/chat/completions/", "https://api.example.com/v1"),
        ("https://api.example.com:8443/openai/", "https://api.example.com:8443/openai"),
        ("https://example.com/", "https://example.com")
    ])
    func normalizesBaseURL(_ input: String, _ expected: String) throws {
        let provider = try ProviderFactory.custom(name: "Local", baseURL: input, model: "m1")
        #expect(provider.baseURL == expected)
    }
}
