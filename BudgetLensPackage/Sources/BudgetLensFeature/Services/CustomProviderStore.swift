import Foundation

protocol CustomProviderStoring {
    func load() throws -> [Provider]
    func save(_ providers: [Provider]) throws
}

enum CustomProviderStoreFailure: Error {
    case encodingFailed
}

struct CustomProviderStore: CustomProviderStoring {
    private let defaults: UserDefaults
    private let key = "customLLMProviders"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> [Provider] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return try JSONDecoder().decode([Provider].self, from: data)
    }

    func save(_ providers: [Provider]) throws {
        guard let data = try? JSONEncoder().encode(providers) else {
            throw CustomProviderStoreFailure.encodingFailed
        }
        defaults.set(data, forKey: key)
    }
}
