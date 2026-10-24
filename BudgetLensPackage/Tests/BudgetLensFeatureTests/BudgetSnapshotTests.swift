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

    @Test func contextContainsOnlyRelevantHistoricalBudgetFields() throws {
        let snapshot = try #require(JSONDecoder().decode(BudgetEnvelope.self, from: BundledSnapshotLoader().load()).data)
        let context = BudgetContext.description(for: snapshot)

        #expect(context.contains("Historical budget snapshot for 2025-05"))
        #expect(context.contains("Groceries (essential): budgeted 60000 cents, spent 71400 cents, remaining -11400 cents, over budget: true"))
        #expect(context.contains("Unallocated budget (separately reported): 41200 cents"))
        #expect(context.contains("unbudgeted spending (separately reported): 18500 cents"))
        #expect(context.contains("Currency is NOT specified"))
        #expect(context.contains("a1b2c3d4") == false)
        #expect(context.contains("USD") == false)
    }

    @Test func amountFormattingUsesMajorUnitsWithoutCurrencySymbol() {
        let amount = BudgetText.amount(cents: 71400)
        #expect(amount.contains("714"))
        #expect(amount.contains("$") == false)
        #expect(BudgetText.percentage(88.2).contains("%"))
    }
}
