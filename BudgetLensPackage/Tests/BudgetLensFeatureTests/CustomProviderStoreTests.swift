import Foundation
import Testing
@testable import BudgetLensFeature

struct CustomProviderStoreTests {
    @Test func roundTripsProviders() throws {
        let defaults = try isolatedDefaults()
        let store = CustomProviderStore(defaults: defaults)
        let provider = try ProviderFactory.custom(name: "Local", baseURL: "https://example.com", model: "m1")
        try store.save([provider])
        #expect(try store.load() == [provider])
    }

    @Test func missingDataLoadsEmpty() throws {
        let store = CustomProviderStore(defaults: try isolatedDefaults())
        #expect(try store.load().isEmpty)
    }

    @Test func corruptedDataThrowsInsteadOfLoadingEmpty() throws {
        let defaults = try isolatedDefaults()
        defaults.set(Data("broken".utf8), forKey: "customLLMProviders")

        #expect(throws: DecodingError.self) { _ = try CustomProviderStore(defaults: defaults).load() }
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let suite = "com.budgetlens.BudgetLens.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
