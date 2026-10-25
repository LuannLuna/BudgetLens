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
    let categoryType: BudgetCategoryType
    let budgetedCents: Int
    let spentCents: Int
    let remainingCents: Int
    let allocationPercentage: Double
    let spentPercentage: Double
    let isOverBudget: Bool

    var id: String { categoryId }
}

enum BudgetCategoryType: Decodable, Sendable, Equatable {
    case essential
    case discretionary
    case savings
    case other(String)

    init(from decoder: any Decoder) throws {
        let name = try decoder.singleValueContainer().decode(String.self)
        switch name {
        case "essential": self = .essential
        case "discretionary": self = .discretionary
        case "savings": self = .savings
        default: self = .other(name)
        }
    }

    /// The name the payload uses, kept verbatim for the model context.
    var name: String {
        switch self {
        case .essential: "essential"
        case .discretionary: "discretionary"
        case .savings: "savings"
        case .other(let name): name
        }
    }
}
