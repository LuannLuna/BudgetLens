import Foundation
import Observation

@MainActor @Observable
final class BudgetAccessState {
    enum Phase {
        case loading
        case needsKey(BudgetSnapshot, providerID: String)
        case ready(BudgetSnapshot)
        case failure(ExperienceFailure)
    }

    private(set) var phase: Phase = .loading
    private(set) var keyRevision = 0
    private(set) var providers: [Provider] = Provider.catalog
    private(set) var keyStates: [ProviderKeyState] = []
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

    func prepare() {
        guard case .loading = phase else { return }
        refreshCatalog()
        do {
            let snapshot = try experience.loadSnapshot()
            if try experience.hasKey(providerID: activeProviderID) {
                phase = .ready(snapshot)
            } else {
                phase = .needsKey(snapshot, providerID: activeProviderID)
            }
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

    func saveKey(_ input: String, providerID: String) throws {
        try experience.saveKey(input, providerID: providerID)
        refreshCatalog()
        if providerID == activeProviderID {
            keyRevision += 1
            if case .needsKey(let snapshot, _) = phase { phase = .ready(snapshot) }
        }
    }

    /// Onboarding path: save the key, make the selected assistant active, and open the budget.
    func connect(_ input: String, providerID: String) throws {
        try experience.saveKey(input, providerID: providerID)
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
        if providerID == activeProviderID {
            keyRevision += 1
            moveOnAfterActiveKeyRemoval()
        }
    }

    func setActiveProvider(_ providerID: String) throws {
        try experience.setActiveProviderID(providerID)
        activeProviderID = providerID
        refreshCatalog()
        do {
            if try experience.hasKey(providerID: providerID) {
                // Switching between keyed assistants keeps the in-memory conversation.
                if case .needsKey(let snapshot, _) = phase { phase = .ready(snapshot) }
            } else if case .ready(let snapshot) = phase {
                phase = .needsKey(snapshot, providerID: providerID)
            } else if case .needsKey(let snapshot, _) = phase {
                phase = .needsKey(snapshot, providerID: providerID)
            }
        } catch let error as ExperienceFailure {
            phase = .failure(error)
        } catch {
            experience.reporter.report(error, context: "provider switching")
            phase = .failure(.keyStorage)
        }
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
        if wasActive {
            keyRevision += 1
            moveOnAfterActiveKeyRemoval()
        }
    }

    private func refreshCatalog() {
        providers = (try? experience.providers()) ?? Provider.catalog
        let active = experience.activeProviderID
        activeProviderID = providers.contains { $0.id == active } ? active : Provider.openAI.id
        keyStates = (try? experience.keyStates()) ?? providers.map { ProviderKeyState(provider: $0, hasKey: false) }
    }

    private func moveOnAfterActiveKeyRemoval() {
        let fallback = keyStates.first { $0.hasKey && $0.provider.id != activeProviderID }
        if let fallback {
            activeProviderID = fallback.provider.id
            do {
                try experience.setActiveProviderID(fallback.provider.id)
            } catch {
                experience.reporter.report(error, context: "fallback provider selection")
            }
            if case .needsKey(let snapshot, _) = phase { phase = .ready(snapshot) }
        } else if case .ready(let snapshot) = phase {
            phase = .needsKey(snapshot, providerID: activeProviderID)
        }
    }
}
