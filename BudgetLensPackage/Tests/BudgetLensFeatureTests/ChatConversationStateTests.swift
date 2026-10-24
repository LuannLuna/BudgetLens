import Testing
@testable import BudgetLensFeature

@MainActor
struct ChatConversationStateTests {
    @Test func retryKeepsOneQuestionAndAddsTheReply() async throws {
        let responder = FlakyResponder()
        let experience = BudgetExperience(
            keyStore: ChatTestKeyStore(),
            client: responder,
            reporter: ChatTestReporter()
        )
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
        #expect(await responder.requestCount == 2)
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

private struct ChatTestKeyStore: APIKeyStoring {
    func read() throws -> String? { "test-only" }
    func save(_ key: String) throws {}
    func clear() throws {}
}

private struct ChatTestReporter: ErrorReporting {
    func report(_ error: any Error, context: String) {}
}
