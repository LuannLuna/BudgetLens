import SwiftUI

struct BudgetView: View {
    let snapshot: BudgetSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LayoutSpace.large) {
                VStack(alignment: .leading, spacing: LayoutSpace.small) {
                    Text("\(BudgetText.period(snapshot.period)) budget snapshot", comment: "Historical budget period heading")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("This is a sample from \(BudgetText.period(snapshot.period)), not a live account balance.", comment: "Historical data notice on budget screen")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: LayoutSpace.medium) {
                    Text("At a glance", comment: "Budget overview section heading")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text("Spent across budget categories", comment: "Label for aggregate budget spending")
                        .foregroundStyle(.secondary)
                    Text(verbatim: "\(BudgetText.amount(cents: snapshot.totalSpentCents)) / \(BudgetText.amount(cents: snapshot.totalBudgetedCents))")
                        .font(.title2.bold())
                    ProgressView(value: min(max(snapshot.spentPercentage / 100, 0), 1))
                        .accessibilityHidden(true)
                    Text("\(BudgetText.percentage(snapshot.spentPercentage)) spent · \(BudgetText.percentage(snapshot.remainingPercentage)) remaining", comment: "Aggregate percentages, not available cash")
                        .font(.subheadline)
                    Divider()
                    metric("Income", comment: "Income in sample snapshot", cents: snapshot.totalIncomeCents)
                    metric("Unallocated budget", comment: "Separately reported unallocated budget", cents: snapshot.unallocatedBudgetCents)
                    metric("Unbudgeted spending", comment: "Separately reported unbudgeted spending", cents: snapshot.unbudgetedSpentCents)
                    Text("These separately reported figures may not reconcile with category totals. Remaining budget isn't necessarily cash available to spend.", comment: "Financial data limitations")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(LayoutSpace.medium)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: LayoutSpace.medium))

                if snapshot.overBudgetCategories.isEmpty == false {
                    VStack(alignment: .leading, spacing: LayoutSpace.small) {
                        Text("Worth reviewing", comment: "Neutral section heading for over-budget categories")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        Text("\(snapshot.overBudgetCategoryCount) categories are over their planned amounts:", comment: "Factual category overage count")
                            .foregroundStyle(.secondary)
                        ForEach(snapshot.overBudgetCategories) { category in
                            Label {
                                Text("\(category.categoryName): \(BudgetText.amount(cents: -category.remainingCents)) over", comment: "Category and amount over budget")
                            } icon: {
                                Image(systemName: "info.circle")
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: LayoutSpace.medium) {
                    Text("Categories (\(snapshot.categoryCount))", comment: "Budget category list heading with count")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    LazyVStack(spacing: LayoutSpace.small) {
                        ForEach(snapshot.categories) { category in
                            BudgetCategoryRow(category: category)
                        }
                    }
                }

                Text("Amounts are shown in major units; the sample doesn't specify a currency.", comment: "Currency disclaimer for sample data")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(LayoutSpace.medium)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func metric(_ title: LocalizedStringKey, comment: StaticString, cents: Int) -> some View {
        LabeledContent {
            Text(verbatim: BudgetText.amount(cents: cents))
        } label: {
            Text(title, comment: comment)
        }
    }
}
