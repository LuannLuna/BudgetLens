import Foundation

enum ProviderStatusMapping {
    static func classify(status: Int, body: Data) -> ProviderFailure? {
        if status == 401 || status == 403 { return .invalidKey }
        if status == 400, bodyMentionsAPIKey(body) { return .invalidKey }
        guard (200..<300).contains(status) else { return .serviceUnavailable }
        return nil
    }

    private static func bodyMentionsAPIKey(_ body: Data) -> Bool {
        String(decoding: body.prefix(1024), as: UTF8.self).localizedCaseInsensitiveContains("api key")
    }
}
