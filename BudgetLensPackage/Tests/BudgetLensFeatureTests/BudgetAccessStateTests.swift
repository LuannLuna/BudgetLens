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

    @Test func failedSwitchKeepsTheCurrentScreenAndAssistant() {
        let (access, store, activeStore) = makeAccess(keys: ["openai": "a"], reporter: SilentReporter())
        access.prepare()
        store.failsOnRead = true

        #expect(throws: ExperienceFailure.keyStorage) { try access.setActiveProvider("gemini") }

        #expect(access.activeProviderID == "openai")
        #expect(activeStore.id == "openai")
        guard case .ready = access.phase else {
            Issue.record("A failed switch should not replace the budget screen")
            return
        }
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

    @Test func unreadableKeysShowANoticeAndRecover() throws {
        let reporter = RecordingReporter()
        let (access, store, _) = makeAccess(keys: ["openai": "a"], reporter: reporter)
        access.prepare()
        #expect(access.catalogFailure == nil)

        store.failsOnRead = true
        try access.saveKey("b", providerID: "openai")
        #expect(access.catalogFailure == .keyStorage)
        #expect(access.keyStates.allSatisfy { $0.hasKey == false })
        #expect(reporter.contexts.contains("key listing"))

        store.failsOnRead = false
        try access.saveKey("c", providerID: "openai")
        #expect(access.catalogFailure == nil)
        #expect(access.hasKey(providerID: "openai"))
    }

    private func makeAccess(
        keys: [String: String] = [:],
        activeID: String = "openai",
        reporter: any ErrorReporting = StrictReporter()
    ) -> (BudgetAccessState, InMemoryKeyStore, InMemoryActiveStore) {
        let store = InMemoryKeyStore(keys: keys)
        let activeStore = InMemoryActiveStore(id: activeID)
        let experience = makeTestExperience(keyStore: store, activeStore: activeStore, reporter: reporter)
        return (BudgetAccessState(experience: experience), store, activeStore)
    }
}
