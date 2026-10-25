import Foundation
import Testing
@testable import BudgetLensFeature

@MainActor
struct BudgetExperienceTests {
    @Test(arguments: [
        (ProviderFailure.invalidKey, ExperienceFailure.invalidKey(providerName: "OpenAI")),
        (ProviderFailure.quotaOrRateLimit, ExperienceFailure.quotaOrRateLimit(providerName: "OpenAI")),
        (ProviderFailure.rejectedRequest, ExperienceFailure.providerConfiguration(providerName: "OpenAI")),
        (ProviderFailure.connection, ExperienceFailure.network),
        (ProviderFailure.unusableReply, ExperienceFailure.unusableReply),
        (ProviderFailure.serviceUnavailable, ExperienceFailure.serviceUnavailable)
    ])
    func providerErrorsMapToRecoverableFailures(_ provider: ProviderFailure, _ expected: ExperienceFailure) async throws {
        let experience = makeTestExperience(resolver: StubResolver(responder: SampleResponder(failure: provider)))
        let snapshot = try experience.loadSnapshot()
        do {
            _ = try await experience.ask("What stands out?", history: [], snapshot: snapshot)
            Issue.record("Expected a mapped provider failure")
        } catch let failure as ExperienceFailure {
            #expect(failure == expected)
        }
    }

    @Test func missingKeyStopsBeforeNetworkRequest() async throws {
        let experience = makeTestExperience(
            keyStore: InMemoryKeyStore(),
            resolver: StubResolver(responder: SampleResponder(failure: .connection))
        )
        let snapshot = try experience.loadSnapshot()
        do {
            _ = try await experience.ask("Question", history: [], snapshot: snapshot)
            Issue.record("Expected a missing key failure")
        } catch let failure as ExperienceFailure {
            #expect(failure == .missingKey)
        }
    }

    @Test(arguments: ["openai", "anthropic", "gemini"])
    func askUsesTheActiveProvider(_ activeID: String) async throws {
        let keys = Dictionary(uniqueKeysWithValues: Provider.catalog.map { ($0.id, "\($0.id)-key") })
        let experience = makeTestExperience(
            keyStore: InMemoryKeyStore(keys: keys),
            resolver: EchoResolver(),
            activeStore: InMemoryActiveStore(id: activeID)
        )
        let snapshot = try experience.loadSnapshot()

        let reply = try await experience.ask("Question", history: [], snapshot: snapshot)

        #expect(reply == "\(activeID):\(activeID)-key")
    }

    @Test func askSendsContextThenRecentHistoryThenQuestion() async throws {
        let responder = RecordingResponder()
        let experience = makeTestExperience(resolver: StubResolver(responder: responder))
        let snapshot = try experience.loadSnapshot()
        let history = (1...8).map { number in
            ChatMessage(role: number.isMultiple(of: 2) ? .assistant : .user, text: "m\(number)")
        }

        _ = try await experience.ask("Now?", history: history, snapshot: snapshot)

        let sent = await responder.messages
        let recent = sent.dropFirst().dropLast()
        #expect(sent.count == 8)
        #expect(sent.first?.content == BudgetContext.description(for: snapshot))
        #expect(recent.map(\.content) == ["m3", "m4", "m5", "m6", "m7", "m8"])
        #expect(recent.map(\.role) == ["user", "assistant", "user", "assistant", "user", "assistant"])
        #expect(sent.last?.content == "Now?")
        #expect(sent.last?.role == "user")
        #expect(await responder.instructions == BudgetContext.instructions)
    }

    @Test func keychainFailuresSurfaceAsKeyStorage() {
        let store = InMemoryKeyStore()
        store.failsOnRead = true
        let experience = makeTestExperience(keyStore: store)

        #expect(throws: ExperienceFailure.keyStorage) { _ = try experience.hasKey(providerID: "openai") }
        #expect(throws: ExperienceFailure.keyStorage) { _ = try experience.keyStates() }
    }

    @Test func customProviderLifecycle() throws {
        let customStore = InMemoryCustomStore()
        let experience = makeTestExperience(customStore: customStore)
        let provider = try experience.addCustomProvider(name: "Local", baseURL: "https://example.com/v1", model: "m1")
        #expect(provider.kind == .openAICompatible)
        #expect(provider.isBuiltIn == false)
        #expect(experience.providers().count == Provider.catalog.count + 1)

        try experience.removeCustomProvider(id: provider.id)
        #expect(experience.providers().count == Provider.catalog.count)
        #expect(customStore.saved.isEmpty)
    }

    @Test func invalidCustomProviderDetailsAreRejectedWithTheReason() {
        let experience = makeTestExperience()

        #expect(throws: ExperienceFailure.invalidProviderDetails(.invalidURL)) {
            _ = try experience.addCustomProvider(name: "Local", baseURL: "http://insecure.example.com", model: "m1")
        }
    }

    @Test func removingActiveCustomProviderFallsBackToOpenAI() throws {
        let activeStore = InMemoryActiveStore()
        let experience = makeTestExperience(activeStore: activeStore)
        let provider = try experience.addCustomProvider(name: "Local", baseURL: "https://example.com", model: "m1")
        try experience.setActiveProviderID(provider.id)
        #expect(activeStore.id == provider.id)

        try experience.removeCustomProvider(id: provider.id)
        #expect(activeStore.id == Provider.openAI.id)
    }

    @Test func unreadableCustomListIsReportedAndIgnored() {
        let customStore = InMemoryCustomStore()
        customStore.loadFailure = TestFailure()
        let reporter = RecordingReporter()
        let experience = makeTestExperience(customStore: customStore, reporter: reporter)

        #expect(experience.providers() == Provider.catalog)
        #expect(reporter.contexts == ["custom provider loading"])
    }

    @Test func customProviderSaveFailureIsAStorageFailureNotAKeyFailure() {
        let customStore = InMemoryCustomStore()
        customStore.saveFailure = TestFailure()
        let experience = makeTestExperience(customStore: customStore)

        #expect(throws: ExperienceFailure.providerStorage) {
            _ = try experience.addCustomProvider(name: "Local", baseURL: "https://example.com", model: "m1")
        }
    }
}

private struct EchoResolver: LLMClientResolving {
    func client(for provider: Provider) -> any LLMResponding { EchoResponder(providerID: provider.id) }
}

private struct EchoResponder: LLMResponding {
    let providerID: String

    func respond(key: String, instructions: String, messages: [ProviderMessage]) async throws -> String {
        "\(providerID):\(key)"
    }
}

private actor RecordingResponder: LLMResponding {
    private(set) var instructions = ""
    private(set) var messages: [ProviderMessage] = []

    func respond(key: String, instructions: String, messages: [ProviderMessage]) async throws -> String {
        self.instructions = instructions
        self.messages = messages
        return "ok"
    }
}
