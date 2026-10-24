import Testing
@testable import BudgetLensFeature

struct ProviderClientRegistryTests {
    let registry = ProviderClientRegistry()

    @Test func routesBuiltInProvidersToMatchingAdapters() {
        #expect(registry.client(for: .openAI) is OpenAIResponseClient)
        #expect(registry.client(for: .anthropic) is AnthropicMessagesClient)
        #expect(registry.client(for: .gemini) is GeminiGenerateContentClient)
        #expect(registry.client(for: .deepSeek) is OpenAICompatibleChatClient)
    }

    @Test func routesCustomProvidersToOpenAICompatibleAdapter() throws {
        let custom = try ProviderFactory.custom(name: "Local", baseURL: "https://example.com", model: "m1")
        #expect(registry.client(for: custom) is OpenAICompatibleChatClient)
    }
}
