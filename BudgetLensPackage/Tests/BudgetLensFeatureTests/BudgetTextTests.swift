import Foundation
import Testing
@testable import BudgetLensFeature

struct BudgetTextTests {
    private let english = Locale(identifier: "en_US")
    private let portuguese = Locale(identifier: "pt_BR")

    @Test func amountsUseMajorUnitsWithLocaleSeparatorsAndNoCurrencySymbol() {
        #expect(BudgetText.amount(cents: 71400, locale: english) == "714.00")
        #expect(BudgetText.amount(cents: 5, locale: english) == "0.05")
        #expect(BudgetText.amount(cents: 1_234_567, locale: english) == "12,345.67")
        #expect(BudgetText.amount(cents: 1_234_567, locale: portuguese) == "12.345,67")
    }

    @Test func percentagesKeepOneDecimalPlace() {
        #expect(BudgetText.percentage(88.2, locale: english) == "88.2%")
        #expect(BudgetText.percentage(100, locale: english) == "100.0%")
        #expect(BudgetText.percentage(88.2, locale: portuguese) == "88,2%")
    }

    @Test func periodShowsMonthAndYearInTheLocale() {
        #expect(BudgetText.period("2025-05", locale: english) == "May 2025")
        #expect(BudgetText.period("2025-05", locale: portuguese).localizedCaseInsensitiveContains("maio"))
    }

    @Test func unreadablePeriodIsShownAsReceived() {
        #expect(BudgetText.period("not-a-period", locale: english) == "not-a-period")
    }
}
