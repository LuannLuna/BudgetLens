import Foundation

enum BudgetText {
    static func amount(cents: Int, locale: Locale = .current) -> String {
        (Decimal(cents) / 100).formatted(.number.precision(.fractionLength(2)).locale(locale))
    }

    static func percentage(_ value: Double, locale: Locale = .current) -> String {
        (value / 100).formatted(.percent.precision(.fractionLength(1)).locale(locale))
    }

    static func period(_ value: String, locale: Locale = .current) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM"
        guard let date = parser.date(from: value) else { return value }
        return date.formatted(.dateTime.month(.wide).year().locale(locale))
    }
}
