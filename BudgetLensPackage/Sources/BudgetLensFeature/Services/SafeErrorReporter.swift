import Foundation
import os

protocol ErrorReporting {
    func report(_ error: any Error, context: String)
}

struct SafeErrorReporter: ErrorReporting {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.budgetlens.BudgetLens", category: "Failures")

    func report(_ error: any Error, context: String) {
        // Only fixed context labels and the error type; never log provider bodies, keys, or budget data.
        logger.error("\(context, privacy: .public): \(String(reflecting: type(of: error)), privacy: .public)")
    }
}
