import Foundation

enum BudgetText {
    static func amount(cents: Int) -> String {
        (Decimal(cents) / 100).formatted(.number.precision(.fractionLength(2)))
    }

    static func percentage(_ value: Double) -> String {
        (value / 100).formatted(.percent.precision(.fractionLength(1)))
    }

    static func period(_ value: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM"
        guard let date = parser.date(from: value) else { return value }
        return date.formatted(.dateTime.month(.wide).year())
    }
}
