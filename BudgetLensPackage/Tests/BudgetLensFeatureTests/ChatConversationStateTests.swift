import Testing
@testable import BudgetLensFeature

@MainActor
struct ChatConversationStateTests {
    @Test func retryKeepsOneQuestionAndAddsTheReply() async throws {
        let responder = FlakyResponder()
        let experience = makeTestExperience(resolver: StubResolver(responder: responder))
        let conversation = ChatConversationState(experience: experience)
        let snapshot = try experience.loadSnapshot()

        conversation.draft = "Which categories are over budget?"
        await conversation.send(snapshot: snapshot)
        #expect(conversation.failure == .network)
        #expect(conversation.messages.count == 1)

        await conversation.retry(snapshot: snapshot)
        #expect(conversation.failure == nil)
        #expect(conversation.messages.count == 2)
        #expect(conversation.messages[0].role == .user)
        #expect(conversation.messages[1].role == .assistant)
        #expect(conversation.messages[1].providerID == "openai")
        #expect(await responder.requestCount == 2)
    }

    @Test func failureFixedInSettingsReturnsTheQuestionToTheComposer() async throws {
        let experience = makeTestExperience(resolver: StubResolver(responder: SampleResponder(failure: .invalidKey)))
        let conversation = ChatConversationState(experience: experience)
        let snapshot = try experience.loadSnapshot()

        conversation.draft = "Which categories are over budget?"
        await conversation.send(snapshot: snapshot)

        #expect(conversation.failure == .invalidKey(providerName: "OpenAI"))
        #expect(conversation.messages.isEmpty)
        #expect(conversation.draft == "Which categories are over budget?")
    }
}

private actor FlakyResponder: LLMResponding {
    private(set) var requestCount = 0

    func respond(key: String, instructions: String, messages: [ProviderMessage]) async throws -> String {
        requestCount += 1
        if requestCount == 1 { throw ProviderFailure.connection }
        return "Groceries and Dining Out are above their planned amounts."
    }
}
