#if DEBUG
import Foundation

/// UI-test seam: answers every question with one provider failure, so error screens can be driven without a live provider.
/// Enabled with `--ui-testing-provider-failure=<invalid-key|quota|rejected|network|unusable|unavailable>`.
struct ForcedFailureResolver: LLMClientResolving {
    static let argumentPrefix = "--ui-testing-provider-failure="

    let failure: ProviderFailure

    static func failure(from arguments: [String]) -> ProviderFailure? {
        guard let argument = arguments.first(where: { $0.hasPrefix(argumentPrefix) }) else { return nil }
        switch argument.dropFirst(argumentPrefix.count) {
        case "invalid-key": return .invalidKey
        case "quota": return .quotaOrRateLimit
        case "rejected": return .rejectedRequest
        case "network": return .connection
        case "unusable": return .unusableReply
        case "unavailable": return .serviceUnavailable
        default: return nil
        }
    }

    func client(for provider: Provider) -> any LLMResponding {
        ForcedFailureResponder(failure: failure)
    }
}

private struct ForcedFailureResponder: LLMResponding {
    let failure: ProviderFailure

    func respond(key: String, instructions: String, messages: [ProviderMessage]) async throws -> String {
        throw failure
    }
}
#endif
