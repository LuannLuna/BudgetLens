import Foundation
import Testing
@testable import BudgetLensFeature

final class InMemoryKeyStore: APIKeyStoring {
    var keys: [String: String]
    /// Returned for assistants without their own entry, for tests that do not care which assistant is asked.
    var defaultKey: String?
    var failsOnRead = false

    init(keys: [String: String] = [:], defaultKey: String? = nil) {
        self.keys = keys
        self.defaultKey = defaultKey
    }

    func read(providerID: String) throws -> String? {
        if failsOnRead { throw KeychainFailure.invalidValue }
        return keys[providerID] ?? defaultKey
    }

    func save(_ key: String, providerID: String) throws { keys[providerID] = key }
    func clear(providerID: String) throws { keys[providerID] = nil }
}

final class InMemoryActiveStore: ActiveProviderStoring {
    var id: String
    init(id: String = "openai") { self.id = id }
    func activeProviderID() -> String { id }
    func setActiveProviderID(_ id: String) { self.id = id }
}

final class InMemoryCustomStore: CustomProviderStoring {
    var saved: [Provider] = []
    var loadFailure: (any Error)?
    var saveFailure: (any Error)?

    func load() throws -> [Provider] {
        if let loadFailure { throw loadFailure }
        return saved
    }

    func save(_ providers: [Provider]) throws {
        if let saveFailure { throw saveFailure }
        saved = providers
    }
}

struct StubResolver: LLMClientResolving {
    let responder: any LLMResponding
    func client(for provider: Provider) -> any LLMResponding { responder }
}

struct SampleResponder: LLMResponding {
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

struct TestFailure: Error {}

struct SilentReporter: ErrorReporting {
    func report(_ error: any Error, context: String) {}
}

/// Fails the test on any report, for flows that must not reach an error path.
struct StrictReporter: ErrorReporting {
    func report(_ error: any Error, context: String) {
        Issue.record("Unexpected error report: \(context)")
    }
}

final class RecordingReporter: ErrorReporting {
    private(set) var contexts: [String] = []
    func report(_ error: any Error, context: String) { contexts.append(context) }
}

@MainActor
func makeTestExperience(
    keyStore: any APIKeyStoring = InMemoryKeyStore(defaultKey: "test-only"),
    resolver: any LLMClientResolving = StubResolver(responder: SampleResponder(reply: "ok")),
    activeStore: any ActiveProviderStoring = InMemoryActiveStore(),
    customStore: any CustomProviderStoring = InMemoryCustomStore(),
    reporter: any ErrorReporting = SilentReporter()
) -> BudgetExperience {
    BudgetExperience(
        snapshotLoader: BundledSnapshotLoader(),
        keyStore: keyStore,
        clientResolver: resolver,
        activeProviderStore: activeStore,
        customProviderStore: customStore,
        reporter: reporter
    )
}
