import Testing
@testable import BudgetLensFeature

struct LegacyKeyMigrationTests {
    @Test func keepsExistingNewKey() {
        #expect(LegacyKeyMigration.plan(newKey: "sk-new", legacyKey: "sk-old") == .none)
    }

    @Test func copiesLegacyKeyWhenNewIsMissing() {
        #expect(LegacyKeyMigration.plan(newKey: nil, legacyKey: "sk-old") == .copy(value: "sk-old"))
    }

    @Test func ignoresEmptyValues() {
        #expect(LegacyKeyMigration.plan(newKey: "", legacyKey: "sk-old") == .copy(value: "sk-old"))
        #expect(LegacyKeyMigration.plan(newKey: nil, legacyKey: "") == .none)
        #expect(LegacyKeyMigration.plan(newKey: nil, legacyKey: nil) == .none)
    }
}
