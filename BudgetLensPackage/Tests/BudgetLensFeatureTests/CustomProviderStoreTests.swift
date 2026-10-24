import Foundation
import Testing
@testable import BudgetLensFeature

struct CustomProviderStoreTests {
    @Test func roundTripsProviders() throws {
        let defaults = try isolatedDefaults()
        let store = CustomProviderStore(defaults: defaults)
        let provider = try ProviderFactory.custom(name: "Local", baseURL: "https://example.com", model: "m1")
        try store.save([provider])
        #expect(store.load() == [provider])
    }

    @Test func corruptedDataLoadsEmpty() throws {
        let defaults = try isolatedDefaults()
        defaults.set(Data("broken".utf8), forKey: "customLLMProviders")
        #expect(CustomProviderStore(defaults: defaults).load().isEmpty)
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let suite = "com.example.BudgetLens.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
