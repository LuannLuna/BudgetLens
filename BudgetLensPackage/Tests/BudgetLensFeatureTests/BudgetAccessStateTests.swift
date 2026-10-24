import Testing
@testable import BudgetLensFeature

@MainActor
struct BudgetAccessStateTests {
    @Test func keyEntryReplacementAndClearChangeLaunchState() throws {
        let store = InMemoryKeyStore()
        let access = BudgetAccessState(experience: BudgetExperience(
            keyStore: store,
            client: NoNetworkResponder(),
            reporter: TestErrorReporter()
        ))

        access.prepare()
        guard case .needsKey = access.phase else {
            Issue.record("Missing key should show entry screen")
            return
        }

        try access.saveKey("sample-one")
        #expect(store.key == "sample-one")
        guard case .ready = access.phase else {
            Issue.record("Saving a key should open the budget")
            return
        }

        try access.saveKey("sample-two")
        #expect(store.key == "sample-two")
        try access.clearKey()
        #expect(store.key == nil)
        guard case .needsKey = access.phase else {
            Issue.record("Clearing a key should return to entry")
            return
        }
    }
}

private final class InMemoryKeyStore: APIKeyStoring {
    var key: String?
    func read() throws -> String? { key }
    func save(_ key: String) throws { self.key = key }
    func clear() throws { key = nil }
}

private struct NoNetworkResponder: LLMResponding {
    func respond(key: String, instructions: String, messages: [ProviderMessage]) async throws -> String {
        "This test does not make network requests."
    }
}

private struct TestErrorReporter: ErrorReporting {
    func report(_ error: any Error, context: String) { Issue.record("Unexpected error in test: \(context)") }
}
