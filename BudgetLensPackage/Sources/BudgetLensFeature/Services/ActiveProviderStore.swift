import Foundation

protocol ActiveProviderStoring {
    func activeProviderID() -> String
    func setActiveProviderID(_ id: String)
}

struct UserDefaultsActiveProviderStore: ActiveProviderStoring {
    private let defaults: UserDefaults
    private let key = "activeLLMProviderID"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [key: Provider.openAI.id])
    }

    func activeProviderID() -> String {
        defaults.string(forKey: key) ?? Provider.openAI.id
    }

    func setActiveProviderID(_ id: String) {
        defaults.set(id, forKey: key)
    }
}
