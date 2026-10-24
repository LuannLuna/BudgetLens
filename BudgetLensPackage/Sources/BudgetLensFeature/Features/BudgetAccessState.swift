import Observation

@MainActor @Observable
final class BudgetAccessState {
    enum Phase {
        case loading
        case needsKey(BudgetSnapshot)
        case ready(BudgetSnapshot)
        case failure(ExperienceFailure)
    }

    private(set) var phase: Phase = .loading
    private(set) var keyRevision = 0
    let experience: BudgetExperience

    init(experience: BudgetExperience) {
        self.experience = experience
    }

    func prepare() {
        guard case .loading = phase else { return }
        do {
            let snapshot = try experience.loadSnapshot()
            phase = try experience.hasKey() ? .ready(snapshot) : .needsKey(snapshot)
        } catch let error as ExperienceFailure {
            phase = .failure(error)
        } catch {
            experience.reporter.report(error, context: "launch preparation")
            phase = .failure(.serviceUnavailable)
        }
    }

    func retryPreparation() {
        phase = .loading
        prepare()
    }

    func saveKey(_ input: String) throws {
        try experience.saveKey(input)
        keyRevision += 1
        if case .needsKey(let snapshot) = phase { phase = .ready(snapshot) }
    }

    func clearKey() throws {
        try experience.clearKey()
        keyRevision += 1
        if case .ready(let snapshot) = phase { phase = .needsKey(snapshot) }
    }
}
