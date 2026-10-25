import Foundation
import Testing
@testable import BudgetLensFeature

struct BudgetSnapshotTests {
    @Test func bundledSampleDecodes() throws {
        let envelope = try JSONDecoder().decode(BudgetEnvelope.self, from: BundledSnapshotLoader().load())
        let snapshot = try #require(envelope.data)

        #expect(envelope.success)
        #expect(snapshot.period == "2025-05")
        #expect(snapshot.categoryCount == 7)
        #expect(snapshot.categories.count == 7)
        #expect(snapshot.overBudgetCategoryCount == 2)
        #expect(snapshot.overBudgetCategories.map(\.categoryName) == ["Groceries", "Dining Out"])
        #expect(snapshot.totalSpentCents == 396800)
    }

    @Test func categoryTypesDecodeKnownAndUnknownNames() throws {
        let data = Data(#"["essential","discretionary","savings","pets"]"#.utf8)

        let types = try JSONDecoder().decode([BudgetCategoryType].self, from: data)

        #expect(types == [.essential, .discretionary, .savings, .other("pets")])
        #expect(types.map(\.name) == ["essential", "discretionary", "savings", "pets"])
    }

    @Test func contextContainsOnlyRelevantHistoricalBudgetFields() throws {
        let snapshot = try #require(JSONDecoder().decode(BudgetEnvelope.self, from: BundledSnapshotLoader().load()).data)
        let context = BudgetContext.description(for: snapshot)

        #expect(context.contains("Historical budget snapshot for 2025-05"))
        #expect(context.contains("Groceries (essential): budgeted 600.00, spent 714.00, remaining -114.00, over budget: true"))
        #expect(context.contains("Unallocated budget (separately reported): 412.00"))
        #expect(context.contains("unbudgeted spending (separately reported): 185.00"))
        #expect(context.contains("Currency is NOT specified"))
        #expect(context.contains("cents") == false)
        #expect(context.contains("a1b2c3d4") == false)
        #expect(context.contains("USD") == false)
    }

    @Test(arguments: [
        (71400, "714.00"),
        (-11400, "-114.00"),
        (5, "0.05"),
        (0, "0.00"),
        (100, "1.00"),
        (123456, "1234.56")
    ])
    func contextAmountsUseMajorUnitsWithAPeriodAndNoGrouping(_ cents: Int, _ expected: String) {
        #expect(BudgetContext.amount(cents) == expected)
    }
}
