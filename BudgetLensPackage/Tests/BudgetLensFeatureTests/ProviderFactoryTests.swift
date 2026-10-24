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
        ("Local", "https://example.com", " ")
    ])
    func rejectsInvalidDetails(_ name: String, _ baseURL: String, _ model: String) {
        #expect(throws: ProviderFactory.ValidationFailure.self) {
            _ = try ProviderFactory.custom(name: name, baseURL: baseURL, model: model)
        }
    }
}
