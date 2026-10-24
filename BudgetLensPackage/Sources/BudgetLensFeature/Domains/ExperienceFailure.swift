enum ExperienceFailure: Error, Equatable {
    case missingKey
    case invalidKey
    case network
    case unusableReply
    case serviceUnavailable
    case snapshotUnavailable
    case keyStorage

    var canRetryQuestion: Bool {
        switch self {
        case .network, .unusableReply, .serviceUnavailable: true
        default: false
        }
    }
}
