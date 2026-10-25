import Foundation

enum ProviderStatusMapping {
    static func classify(status: Int, body: Data) -> ProviderFailure? {
        switch status {
        case 401, 403: .invalidKey
        case 400 where bodyMentionsAPIKey(body): .invalidKey
        case 402, 429: .quotaOrRateLimit
        case 400, 404, 422: .rejectedRequest
        case 200..<300: nil
        default: .serviceUnavailable
        }
    }

    private static func bodyMentionsAPIKey(_ body: Data) -> Bool {
        // lowercased() is locale-independent; localizedCaseInsensitiveContains is not (e.g. Turkish "I").
        String(decoding: body.prefix(1024), as: UTF8.self).lowercased().contains("api key")
    }
}
