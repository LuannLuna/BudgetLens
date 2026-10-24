enum ExperienceFailure: Error, Equatable {
    case missingKey
    case invalidKey(providerName: String)
    case network
    case unusableReply
    case serviceUnavailable
    case snapshotUnavailable
    case keyStorage
    case invalidProvider
    case invalidProviderDetails(String)

    var canRetryQuestion: Bool {
        switch self {
        case .network, .unusableReply, .serviceUnavailable: true
        default: false
        }
    }

    var requiresKeyFix: Bool {
        switch self {
        case .missingKey, .invalidKey, .keyStorage, .invalidProvider: true
        default: false
        }
    }
}
