import SwiftUI

struct BudgetCategoryRow: View {
    let category: BudgetCategory

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutSpace.small) {
            HStack(alignment: .firstTextBaseline, spacing: LayoutSpace.medium) {
                Image(systemName: category.categoryIcon)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: LayoutSpace.small) {
                    Text(verbatim: category.categoryName)
                        .font(.headline)
                    categoryKind
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if category.isOverBudget {
                    Image(systemName: "exclamationmark.circle")
                        .accessibilityHidden(true)
                }
            }
            Text("\(BudgetText.amount(cents: category.spentCents)) spent of \(BudgetText.amount(cents: category.budgetedCents)) budgeted", comment: "Category spending relative to its budget")
            ProgressView(value: min(max(category.spentPercentage / 100, 0), 1))
                .accessibilityHidden(true)
            HStack {
                Text(verbatim: BudgetText.percentage(category.spentPercentage))
                Spacer()
                if category.isOverBudget {
                    Text("\(BudgetText.amount(cents: -category.remainingCents)) over budget", comment: "Category amount over budget")
                } else if category.remainingCents == 0 {
                    Text("On budget", comment: "Category has exactly met its budget")
                } else {
                    Text("\(BudgetText.amount(cents: category.remainingCents)) remaining", comment: "Category unspent planned amount")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(LayoutSpace.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: LayoutSpace.medium))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var categoryKind: some View {
        switch category.categoryType {
        case .essential: Text("Essential", comment: "Essential budget category type")
        case .discretionary: Text("Discretionary", comment: "Discretionary budget category type")
        case .savings: Text("Savings", comment: "Savings budget category type")
        case .other: Text("Category", comment: "Fallback for an unknown category type")
        }
    }
}
