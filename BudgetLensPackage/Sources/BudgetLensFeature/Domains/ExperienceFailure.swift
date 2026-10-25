enum ExperienceFailure: Error, Equatable {
    case missingKey
    case invalidKey(providerName: String)
    case quotaOrRateLimit(providerName: String)
    case providerConfiguration(providerName: String)
    case network
    case unusableReply
    case serviceUnavailable
    case snapshotUnavailable
    case keyStorage
    case invalidProvider
    case invalidProviderDetails(String)

    var canRetryQuestion: Bool {
        switch self {
        case .network, .unusableReply, .serviceUnavailable, .quotaOrRateLimit: true
        default: false
        }
    }

    var needsSettings: Bool {
        switch self {
        case .missingKey, .invalidKey, .providerConfiguration, .keyStorage, .invalidProvider: true
        default: false
        }
    }
}
