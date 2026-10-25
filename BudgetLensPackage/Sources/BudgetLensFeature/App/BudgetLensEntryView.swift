import SwiftUI

/// The package's only public view: composes the production dependencies and starts the launch flow.
@MainActor
public struct BudgetLensEntryView: View {
    @State private var access = BudgetAccessState(experience: BudgetExperience())

    public init() {}

    public var body: some View {
        BudgetLensRootView(access: access)
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--ui-testing-reset") {
                    access.resetForAutomatedTests()
                }
                #endif
                access.prepare()
            }
    }
}
