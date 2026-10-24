import Foundation
import Testing
@testable import BudgetLensFeature

@MainActor
struct BudgetExperienceTests {
    @Test(arguments: [
        (ProviderFailure.invalidKey, ExperienceFailure.invalidKey),
        (ProviderFailure.connection, ExperienceFailure.network),
        (ProviderFailure.unusableReply, ExperienceFailure.unusableReply),
        (ProviderFailure.serviceUnavailable, ExperienceFailure.serviceUnavailable)
    ])
    func providerErrorsMapToRecoverableFailures(_ provider: ProviderFailure, _ expected: ExperienceFailure) async throws {
        let experience = BudgetExperience(
            keyStore: SampleKeyStore(key: "test-only"),
            client: SampleResponder(failure: provider),
            reporter: SilentTestReporter()
        )
        let snapshot = try experience.loadSnapshot()
        do {
            _ = try await experience.ask("What stands out?", history: [], snapshot: snapshot)
            Issue.record("Expected a mapped provider failure")
        } catch let failure as ExperienceFailure {
            #expect(failure == expected)
        }
    }

    @Test func missingKeyStopsBeforeNetworkRequest() async throws {
        let experience = BudgetExperience(
            keyStore: SampleKeyStore(key: nil),
            client: SampleResponder(failure: .connection),
            reporter: SilentTestReporter()
        )
        let snapshot = try experience.loadSnapshot()
        do {
            _ = try await experience.ask("Question", history: [], snapshot: snapshot)
            Issue.record("Expected a missing key failure")
        } catch let failure as ExperienceFailure {
            #expect(failure == .missingKey)
        }
    }
}

private struct SampleKeyStore: APIKeyStoring {
    let key: String?
    func read() throws -> String? { key }
    func save(_ key: String) throws {}
    func clear() throws {}
}

private struct SampleResponder: LLMResponding {
    let failure: ProviderFailure
    func respond(key: String, instructions: String, messages: [ProviderMessage]) async throws -> String {
        throw failure
    }
}

private struct SilentTestReporter: ErrorReporting {
    func report(_ error: any Error, context: String) {}
}
