import Foundation

struct BudgetEnvelope: Decodable, Sendable {
    let success: Bool
    let data: BudgetSnapshot?
}

struct BudgetSnapshot: Decodable, Sendable {
    let period: String
    let totalBudgetedCents: Int
    let totalSpentCents: Int
    let totalIncomeCents: Int
    let unallocatedBudgetCents: Int
    let unbudgetedSpentCents: Int
    let spentPercentage: Double
    let remainingPercentage: Double
    let categoryCount: Int
    let overBudgetCategoryCount: Int
    let categories: [BudgetCategory]

    var overBudgetCategories: [BudgetCategory] {
        categories.filter(\.isOverBudget)
    }
}

struct BudgetCategory: Decodable, Identifiable, Sendable {
    let categoryId: String
    let categoryName: String
    let categoryIcon: String
    let categoryType: String
    let budgetedCents: Int
    let spentCents: Int
    let remainingCents: Int
    let allocationPercentage: Double
    let spentPercentage: Double
    let isOverBudget: Bool

    var id: String { categoryId }
}
