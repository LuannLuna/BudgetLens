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
        let experience = makeExperience(key: "test-only", responder: SampleResponder(failure: provider))
        let snapshot = try experience.loadSnapshot()
        do {
            _ = try await experience.ask("What stands out?", history: [], snapshot: snapshot)
            Issue.record("Expected a mapped provider failure")
        } catch let failure as ExperienceFailure {
            #expect(failure == expected)
        }
    }

    @Test func missingKeyStopsBeforeNetworkRequest() async throws {
        let experience = makeExperience(key: nil, responder: SampleResponder(failure: .connection))
        let snapshot = try experience.loadSnapshot()
        do {
            _ = try await experience.ask("Question", history: [], snapshot: snapshot)
            Issue.record("Expected a missing key failure")
        } catch let failure as ExperienceFailure {
            #expect(failure == .missingKey)
        }
    }

    @Test func askUsesTheActiveProvider() async throws {
        let experience = makeExperience(
            key: "anthropic-key",
            responder: SampleResponder(reply: "anthropic-answer"),
            activeID: "anthropic"
        )
        let snapshot = try experience.loadSnapshot()
        let reply = try await experience.ask("Question", history: [], snapshot: snapshot)
        #expect(reply == "anthropic-answer")
    }

    @Test func askSendsContextThenRecentHistoryThenQuestion() async throws {
        let responder = RecordingResponder()
        let experience = makeExperience(responder: responder)
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
        let experience = makeExperience(keyStore: UnreadableKeyStore())

        #expect(throws: ExperienceFailure.keyStorage) { _ = try experience.hasKey(providerID: "openai") }
        #expect(throws: ExperienceFailure.keyStorage) { _ = try experience.keyStates() }
    }

    @Test func customProviderLifecycle() throws {
        let customStore = InMemoryCustomStore()
        let experience = makeExperience(customStore: customStore)
        let provider = try experience.addCustomProvider(name: "Local", baseURL: "https://example.com/v1", model: "m1")
        #expect(provider.kind == .openAICompatible)
        #expect(provider.isBuiltIn == false)
        #expect(experience.providers().count == Provider.catalog.count + 1)

        try experience.removeCustomProvider(id: provider.id)
        #expect(experience.providers().count == Provider.catalog.count)
        #expect(customStore.saved.isEmpty)
    }

    @Test func invalidCustomProviderDetailsAreRejected() {
        let experience = makeExperience()
        do {
            _ = try experience.addCustomProvider(name: "Local", baseURL: "http://insecure.example.com", model: "m1")
            Issue.record("Expected a validation failure")
        } catch let failure as ExperienceFailure {
            guard case .invalidProviderDetails = failure else {
                Issue.record("Unexpected failure: \(failure)")
                return
            }
        } catch {
            Issue.record("Unexpected error type: \(type(of: error))")
        }
    }

    @Test func removingActiveCustomProviderFallsBackToOpenAI() throws {
        let activeStore = InMemoryActiveStore()
        let experience = makeExperience(activeStore: activeStore)
        let provider = try experience.addCustomProvider(name: "Local", baseURL: "https://example.com", model: "m1")
        try experience.setActiveProviderID(provider.id)
        #expect(activeStore.id == provider.id)

        try experience.removeCustomProvider(id: provider.id)
        #expect(activeStore.id == Provider.openAI.id)
    }

    private func makeExperience(
        key: String? = "test-only",
        keyStore: (any APIKeyStoring)? = nil,
        responder: any LLMResponding = SampleResponder(reply: "ok"),
        activeID: String = "openai",
        customStore: any CustomProviderStoring = InMemoryCustomStore(),
        activeStore: InMemoryActiveStore = InMemoryActiveStore()
    ) -> BudgetExperience {
        BudgetExperience(
            snapshotLoader: BundledSnapshotLoader(),
            keyStore: keyStore ?? SampleKeyStore(key: key),
            clientResolver: SampleResolver(responder: responder),
            activeProviderStore: activeStore,
            customProviderStore: customStore,
            reporter: SilentTestReporter()
        )
    }
}

private struct SampleKeyStore: APIKeyStoring {
    let key: String?
    func read(providerID: String) throws -> String? { key }
    func save(_ key: String, providerID: String) throws {}
    func clear(providerID: String) throws {}
}

private struct UnreadableKeyStore: APIKeyStoring {
    func read(providerID: String) throws -> String? { throw KeychainFailure.invalidValue }
    func save(_ key: String, providerID: String) throws {}
    func clear(providerID: String) throws {}
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

private struct SampleResolver: LLMClientResolving {
    let responder: any LLMResponding
    func client(for provider: Provider) -> any LLMResponding { responder }
}

private struct SampleResponder: LLMResponding {
    let failure: ProviderFailure?
    let reply: String

    init(failure: ProviderFailure) {
        self.failure = failure
        self.reply = ""
    }

    init(reply: String) {
        self.failure = nil
        self.reply = reply
    }

    func respond(key: String, instructions: String, messages: [ProviderMessage]) async throws -> String {
        if let failure { throw failure }
        return reply
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

private struct SilentTestReporter: ErrorReporting {
    func report(_ error: any Error, context: String) {}
}
