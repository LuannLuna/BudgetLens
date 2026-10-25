import SwiftUI

/// The package's only public view: composes the production dependencies and starts the launch flow.
@MainActor
public struct BudgetLensEntryView: View {
    @State private var access = Self.makeAccess()

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

    private static func makeAccess() -> BudgetAccessState {
        BudgetAccessState(
            experience: BudgetExperience(
                snapshotLoader: BundledSnapshotLoader(),
                keyStore: KeychainAPIKeyStore(),
                clientResolver: ProviderClientRegistry(),
                activeProviderStore: UserDefaultsActiveProviderStore(),
                customProviderStore: CustomProviderStore(),
                reporter: SafeErrorReporter()
            )
        )
    }
}
