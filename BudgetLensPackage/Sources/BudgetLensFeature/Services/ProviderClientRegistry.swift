import Foundation

protocol LLMClientResolving {
    func client(for provider: Provider) -> any LLMResponding
}

struct ProviderClientRegistry: LLMClientResolving {
    let session: URLSession

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    func client(for provider: Provider) -> any LLMResponding {
        switch provider.kind {
        case .openAIResponses:
            OpenAIResponseClient(provider: provider, session: session)
        case .anthropicMessages:
            AnthropicMessagesClient(provider: provider, session: session)
        case .gemini:
            GeminiGenerateContentClient(provider: provider, session: session)
        case .openAICompatible:
            OpenAICompatibleChatClient(provider: provider, session: session)
        }
    }
}
