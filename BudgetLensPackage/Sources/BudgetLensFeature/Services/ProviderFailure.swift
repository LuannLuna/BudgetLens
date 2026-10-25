enum ProviderFailure: Error {
    case invalidKey
    case quotaOrRateLimit
    case rejectedRequest
    case connection
    case unusableReply
    case serviceUnavailable
}
