import Testing
@testable import BudgetLensFeature

@MainActor
struct BudgetAccessStateTests {
    @Test func keyEntryReplacementAndClearChangeLaunchState() throws {
        let (access, store, _) = makeAccess()
        access.prepare()
        guard case .needsKey(_, let providerID) = access.phase else {
            Issue.record("Missing key should show entry screen")
            return
        }
        #expect(providerID == "openai")

        try access.saveKey("sample-one", providerID: "openai")
        #expect(store.keys["openai"] == "sample-one")
        guard case .ready = access.phase else {
            Issue.record("Saving a key should open the budget")
            return
        }

        try access.saveKey("sample-two", providerID: "openai")
        #expect(store.keys["openai"] == "sample-two")

        try access.clearKey(providerID: "openai")
        #expect(store.keys["openai"] == nil)
        guard case .needsKey = access.phase else {
            Issue.record("Clearing the only key should return to entry")
            return
        }
    }

    @Test func switchingBetweenKeyedAssistantsKeepsConversation() throws {
        let (access, _, _) = makeAccess(keys: ["openai": "a", "anthropic": "b"])
        access.prepare()
        guard case .ready = access.phase else {
            Issue.record("Saved key should open the budget")
            return
        }
        let revision = access.keyRevision

        try access.setActiveProvider("anthropic")
        #expect(access.activeProviderID == "anthropic")
        guard case .ready = access.phase else {
            Issue.record("Switching to a keyed assistant should keep the budget open")
            return
        }
        #expect(access.keyRevision == revision)
    }

    @Test func switchingToKeylessAssistantOpensEntry() throws {
        let (access, _, _) = makeAccess(keys: ["openai": "a"])
        access.prepare()
        try access.setActiveProvider("gemini")
        guard case .needsKey(_, let providerID) = access.phase else {
            Issue.record("Switching to a keyless assistant should open entry")
            return
        }
        #expect(providerID == "gemini")
    }

    @Test func clearingActiveKeyFallsBackToAnotherKeyedAssistant() throws {
        let (access, _, activeStore) = makeAccess(keys: ["openai": "a", "anthropic": "b"])
        access.prepare()
        try access.clearKey(providerID: "openai")
        #expect(access.activeProviderID == "anthropic")
        #expect(activeStore.id == "anthropic")
        guard case .ready = access.phase else {
            Issue.record("Fallback assistant should keep the budget open")
            return
        }
    }

    @Test func clearingOnlyKeyReturnsToEntry() throws {
        let (access, _, _) = makeAccess(keys: ["openai": "a"])
        access.prepare()
        try access.clearKey(providerID: "openai")
        guard case .needsKey(_, let providerID) = access.phase else {
            Issue.record("Clearing the only key should return to entry")
            return
        }
        #expect(providerID == "openai")
    }

    @Test func addingCustomProviderAppearsInCatalog() throws {
        let (access, _, _) = makeAccess()
        access.prepare()
        let provider = try access.addCustomProvider(name: "Local", baseURL: "https://example.com", model: "m1")
        #expect(provider.isBuiltIn == false)
        #expect(access.providers.contains(provider))
    }

    @Test func connectingSelectedAssistantActivatesItAndConfirms() throws {
        let (access, store, activeStore) = makeAccess()
        access.prepare()

        try access.connect("gemini-key", providerID: "gemini")

        #expect(store.keys["gemini"] == "gemini-key")
        #expect(access.activeProviderID == "gemini")
        #expect(activeStore.id == "gemini")
        #expect(access.justConnectedProviderName == "Gemini")
        guard case .ready = access.phase else {
            Issue.record("Connecting a non-active assistant should open the budget")
            return
        }

        access.dismissConnectionNotice()
        #expect(access.justConnectedProviderName == nil)
    }

    @Test func connectingWithAnEmptyFieldReusesTheSavedKey() throws {
        let (access, store, activeStore) = makeAccess(keys: ["anthropic": "saved"])
        access.prepare()
        guard case .needsKey = access.phase else {
            Issue.record("The active assistant has no key, so entry should show")
            return
        }
        #expect(access.hasKey(providerID: "anthropic"))
        #expect(access.hasKey(providerID: "openai") == false)

        try access.connect("  ", providerID: "anthropic")

        #expect(store.keys["anthropic"] == "saved")
        #expect(activeStore.id == "anthropic")
        #expect(access.justConnectedProviderName == "Anthropic")
        guard case .ready = access.phase else {
            Issue.record("Reusing a saved key should open the budget")
            return
        }
    }

    @Test func connectingWithAnEmptyFieldNeedsASavedKey() {
        let (access, _, _) = makeAccess()
        access.prepare()

        #expect(throws: ExperienceFailure.missingKey) { try access.connect("", providerID: "openai") }
        guard case .needsKey = access.phase else {
            Issue.record("A failed connect should stay on key entry")
            return
        }
    }

    @Test func replacingTheActiveKeyKeepsTheConversation() throws {
        let (access, store, _) = makeAccess(keys: ["openai": "old"])
        access.prepare()
        let revision = access.keyRevision

        try access.saveKey("new", providerID: "openai")

        #expect(store.keys["openai"] == "new")
        #expect(access.keyRevision == revision)
        guard case .ready = access.phase else {
            Issue.record("Replacing a key should keep the budget open")
            return
        }
    }

    @Test func clearingTheActiveKeyEndsTheConversation() throws {
        let (access, _, _) = makeAccess(keys: ["openai": "a", "anthropic": "b"])
        access.prepare()
        let revision = access.keyRevision

        try access.clearKey(providerID: "openai")

        #expect(access.keyRevision == revision + 1)
    }

    private func makeAccess(
        keys: [String: String] = [:],
        activeID: String = "openai"
    ) -> (BudgetAccessState, InMemoryKeyStore, InMemoryActiveStore) {
        let store = InMemoryKeyStore(keys: keys)
        let activeStore = InMemoryActiveStore(id: activeID)
        let experience = BudgetExperience(
            snapshotLoader: BundledSnapshotLoader(),
            keyStore: store,
            clientResolver: TestResolver(responder: NoNetworkResponder()),
            activeProviderStore: activeStore,
            customProviderStore: InMemoryCustomStore(),
            reporter: TestErrorReporter()
        )
        return (BudgetAccessState(experience: experience), store, activeStore)
    }
}

private final class InMemoryKeyStore: APIKeyStoring {
    var keys: [String: String]
    init(keys: [String: String] = [:]) { self.keys = keys }
    func read(providerID: String) throws -> String? { keys[providerID] }
    func save(_ key: String, providerID: String) throws { keys[providerID] = key }
    func clear(providerID: String) throws { keys[providerID] = nil }
}

private final class InMemoryActiveStore: ActiveProviderStoring {
    var id: String
    init(id: String = "openai") { self.id = id }
    func activeProviderID() -> String { id }
    func setActiveProviderID(_ id: String) { self.id = id }
}

private final class InMemoryCustomStore: CustomProviderStoring {
    var saved: [Provider] = []
    func load() -> [Provider] { saved }
    func save(_ providers: [Provider]) throws { saved = providers }
}

private struct TestResolver: LLMClientResolving {
    let responder: any LLMResponding
    func client(for provider: Provider) -> any LLMResponding { responder }
}

private struct NoNetworkResponder: LLMResponding {
    func respond(key: String, instructions: String, messages: [ProviderMessage]) async throws -> String {
        "This test does not make network requests."
    }
}

private struct TestErrorReporter: ErrorReporting {
    func report(_ error: any Error, context: String) { Issue.record("Unexpected error in test: \(context)") }
}
