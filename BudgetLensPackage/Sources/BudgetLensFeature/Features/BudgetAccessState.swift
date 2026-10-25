import Foundation
import Observation

@MainActor @Observable
final class BudgetAccessState {
    private(set) var phase: Phase = .loading
    private(set) var keyRevision = 0
    private(set) var providers: [Provider] = Provider.catalog
    private(set) var keyStates: [ProviderKeyState] = []
    private(set) var catalogFailure: ExperienceFailure?
    private(set) var activeProviderID = Provider.openAI.id
    private(set) var justConnectedProviderName: String?
    let experience: BudgetExperience

    init(experience: BudgetExperience) {
        self.experience = experience
    }

    var needsKeyProviderID: String {
        if case .needsKey(_, let providerID) = phase { return providerID }
        return activeProviderID
    }

    var activeProviderName: String {
        providerName(for: activeProviderID) ?? activeProviderID
    }

    func providerName(for id: String?) -> String? {
        guard let id else { return nil }
        return providers.first { $0.id == id }?.name
    }

    func hasKey(providerID: String) -> Bool {
        keyStates.first { $0.provider.id == providerID }?.hasKey == true
    }

    func prepare() {
        guard case .loading = phase else { return }
        refreshCatalog()
        do {
            let snapshot = try experience.loadSnapshot()
            let hasKey = try experience.hasKey(providerID: activeProviderID)
            phase = hasKey ? .ready(snapshot) : .needsKey(snapshot, providerID: activeProviderID)
        } catch let error as ExperienceFailure {
            phase = .failure(error)
        } catch {
            experience.report(error, context: "launch preparation")
            phase = .failure(.serviceUnavailable)
        }
    }

    func retryPreparation() {
        phase = .loading
        prepare()
    }

    /// Replacing a key keeps the in-memory chat; clearing or removing the active assistant ends it.
    func saveKey(_ input: String, providerID: String) throws {
        try experience.saveKey(input, providerID: providerID)
        refreshCatalog()
        if providerID == activeProviderID, case .needsKey(let snapshot, _) = phase { phase = .ready(snapshot) }
    }

    /// Onboarding path: save the key (or reuse the saved one when the field is empty), make the selected assistant active, and open the budget.
    func connect(_ input: String, providerID: String) throws {
        let reusesSavedKey = input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasKey(providerID: providerID)
        if reusesSavedKey == false {
            try experience.saveKey(input, providerID: providerID)
        }
        try experience.setActiveProviderID(providerID)
        activeProviderID = providerID
        justConnectedProviderName = experience.providerName(for: providerID) ?? providerID
        refreshCatalog()
        keyRevision += 1
        if case .needsKey(let snapshot, _) = phase { phase = .ready(snapshot) }
    }

    func dismissConnectionNotice() {
        justConnectedProviderName = nil
    }

    #if DEBUG
    func resetForAutomatedTests() {
        experience.resetForAutomatedTests()
        keyRevision += 1
    }
    #endif

    func clearKey(providerID: String) throws {
        try experience.clearKey(providerID: providerID)
        refreshCatalog()
        if providerID == activeProviderID { moveOnAfterActiveKeyRemoval() }
    }

    /// Throws before changing anything, so a failed switch leaves the current screen and assistant as they were.
    /// Switching between keyed assistants keeps the in-memory conversation.
    func setActiveProvider(_ providerID: String) throws {
        let hasKey = try experience.hasKey(providerID: providerID)
        try experience.setActiveProviderID(providerID)
        activeProviderID = providerID
        refreshCatalog()
        phase = phase.routed(hasKey: hasKey, providerID: providerID)
    }

    @discardableResult
    func addCustomProvider(name: String, baseURL: String, model: String) throws -> Provider {
        let provider = try experience.addCustomProvider(name: name, baseURL: baseURL, model: model)
        refreshCatalog()
        return provider
    }

    func removeCustomProvider(id: String) throws {
        let wasActive = id == activeProviderID
        try experience.removeCustomProvider(id: id)
        refreshCatalog()
        if wasActive { moveOnAfterActiveKeyRemoval() }
    }

    private func refreshCatalog() {
        providers = experience.providers()
        let active = experience.activeProviderID
        activeProviderID = providers.contains { $0.id == active } ? active : Provider.openAI.id
        do {
            keyStates = try experience.keyStates()
            catalogFailure = nil
        } catch {
            // The experience already reported it; show every row as "No key" plus a notice instead of hiding the problem.
            keyStates = providers.map { ProviderKeyState(provider: $0, hasKey: false) }
            catalogFailure = error as? ExperienceFailure ?? .keyStorage
        }
    }

    private func moveOnAfterActiveKeyRemoval() {
        keyRevision += 1
        let fallback = keyStates.first { $0.hasKey && $0.provider.id != activeProviderID }
        if let fallback {
            activeProviderID = fallback.provider.id
            do {
                try experience.setActiveProviderID(fallback.provider.id)
            } catch {
                experience.report(error, context: "fallback provider selection")
            }
        }
        phase = phase.routed(hasKey: fallback != nil, providerID: activeProviderID)
    }
}
