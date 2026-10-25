extension BudgetAccessState {
    enum Phase {
        case loading
        case needsKey(BudgetSnapshot, providerID: String)
        case ready(BudgetSnapshot)
        case failure(ExperienceFailure)

        /// The screen once an assistant's key state is known; loading and failure are left as they are.
        func routed(hasKey: Bool, providerID: String) -> Phase {
            switch self {
            case .needsKey(let snapshot, _), .ready(let snapshot):
                hasKey ? .ready(snapshot) : .needsKey(snapshot, providerID: providerID)
            case .loading, .failure:
                self
            }
        }
    }
}
