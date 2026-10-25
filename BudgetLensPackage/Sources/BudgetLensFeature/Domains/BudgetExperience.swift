import Foundation

@MainActor
struct BudgetExperience {
    private let snapshotLoader: BundledSnapshotLoader
    private let keyStore: any APIKeyStoring
    private let clientResolver: any LLMClientResolving
    private let activeProviderStore: any ActiveProviderStoring
    private let customProviderStore: any CustomProviderStoring
    private let reporter: any ErrorReporting

    init(
        snapshotLoader: BundledSnapshotLoader,
        keyStore: any APIKeyStoring,
        clientResolver: any LLMClientResolving,
        activeProviderStore: any ActiveProviderStoring,
        customProviderStore: any CustomProviderStoring,
        reporter: any ErrorReporting
    ) {
        self.snapshotLoader = snapshotLoader
        self.keyStore = keyStore
        self.clientResolver = clientResolver
        self.activeProviderStore = activeProviderStore
        self.customProviderStore = customProviderStore
        self.reporter = reporter
    }

    /// Lets Features report failures without reaching into Services.
    func report(_ error: any Error, context: String) {
        reporter.report(error, context: context)
    }

    var activeProviderID: String {
        activeProviderStore.activeProviderID()
    }

    var activeProvider: Provider {
        provider(matching: activeProviderID) ?? .openAI
    }

    func providers() -> [Provider] {
        Provider.catalog + customProviders()
    }

    func provider(matching id: String) -> Provider? {
        providers().first { $0.id == id }
    }

    /// An unreadable custom-assistant list is reported and treated as empty, so the built-in assistants keep working.
    private func customProviders() -> [Provider] {
        do {
            return try customProviderStore.load()
        } catch {
            reporter.report(error, context: "custom provider loading")
            return []
        }
    }

    func providerName(for id: String?) -> String? {
        guard let id else { return nil }
        return provider(matching: id)?.name
    }

    func loadSnapshot() throws -> BudgetSnapshot {
        do {
            let envelope = try JSONDecoder().decode(BudgetEnvelope.self, from: snapshotLoader.load())
            guard envelope.success, let snapshot = envelope.data else {
                throw ExperienceFailure.snapshotUnavailable
            }
            return snapshot
        } catch {
            reporter.report(error, context: "snapshot loading")
            throw ExperienceFailure.snapshotUnavailable
        }
    }

    func keyStates() throws -> [ProviderKeyState] {
        do {
            return try providers().map { provider in
                ProviderKeyState(provider: provider, hasKey: try keyStore.read(providerID: provider.id)?.isEmpty == false)
            }
        } catch {
            reporter.report(error, context: "key listing")
            throw ExperienceFailure.keyStorage
        }
    }

    func hasKey(providerID: String) throws -> Bool {
        do {
            return try keyStore.read(providerID: providerID)?.isEmpty == false
        } catch {
            reporter.report(error, context: "key checking")
            throw ExperienceFailure.keyStorage
        }
    }

    func saveKey(_ input: String, providerID: String) throws {
        let key = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.isEmpty == false else { throw ExperienceFailure.missingKey }
        do {
            try keyStore.save(key, providerID: providerID)
        } catch {
            reporter.report(error, context: "key saving")
            throw ExperienceFailure.keyStorage
        }
    }

    func clearKey(providerID: String) throws {
        do {
            try keyStore.clear(providerID: providerID)
        } catch {
            reporter.report(error, context: "key clearing")
            throw ExperienceFailure.keyStorage
        }
    }

    func setActiveProviderID(_ id: String) throws {
        guard provider(matching: id) != nil else { throw ExperienceFailure.invalidProvider }
        activeProviderStore.setActiveProviderID(id)
    }

    func addCustomProvider(name: String, baseURL: String, model: String) throws -> Provider {
        let provider: Provider
        do {
            provider = try ProviderFactory.custom(name: name, baseURL: baseURL, model: model)
        } catch let failure as ProviderFactory.ValidationFailure {
            throw ExperienceFailure.invalidProviderDetails(failure)
        }
        do {
            var customs = customProviders()
            customs.append(provider)
            try customProviderStore.save(customs)
            return provider
        } catch {
            reporter.report(error, context: "custom provider saving")
            throw ExperienceFailure.providerStorage
        }
    }

    func removeCustomProvider(id: String) throws {
        guard provider(matching: id)?.isBuiltIn == false else { throw ExperienceFailure.invalidProvider }
        do {
            try keyStore.clear(providerID: id)
        } catch {
            // The provider is removed regardless; the key may already be absent.
            reporter.report(error, context: "custom provider key clearing")
        }
        var customs = customProviders()
        customs.removeAll { $0.id == id }
        do {
            try customProviderStore.save(customs)
        } catch {
            reporter.report(error, context: "custom provider removing")
            throw ExperienceFailure.providerStorage
        }
        if activeProviderStore.activeProviderID() == id {
            activeProviderStore.setActiveProviderID(Provider.openAI.id)
        }
    }

    #if DEBUG
    /// Clears keys and assistant preferences so UI tests start from a known first-launch state.
    func resetForAutomatedTests() {
        for provider in providers() {
            do {
                try keyStore.clear(providerID: provider.id)
            } catch {
                reporter.report(error, context: "test reset key removal")
            }
        }
        do {
            try customProviderStore.save([])
        } catch {
            reporter.report(error, context: "test reset custom assistants")
        }
        activeProviderStore.setActiveProviderID(Provider.openAI.id)
    }
    #endif

    func ask(_ question: String, history: [ChatMessage], snapshot: BudgetSnapshot) async throws -> String {
        let provider = activeProvider
        let key: String
        do {
            guard let saved = try keyStore.read(providerID: provider.id), saved.isEmpty == false else {
                throw ExperienceFailure.missingKey
            }
            key = saved
        } catch let error as ExperienceFailure {
            throw error
        } catch {
            reporter.report(error, context: "key reading for chat")
            throw ExperienceFailure.keyStorage
        }

        let previous = history.suffix(6).map { message in
            ProviderMessage(role: message.role == .user ? "user" : "assistant", content: message.text)
        }
        let messages = [
            ProviderMessage(role: "user", content: BudgetContext.description(for: snapshot))
        ] + previous + [ProviderMessage(role: "user", content: question)]

        do {
            return try await clientResolver.client(for: provider).respond(
                key: key,
                instructions: BudgetContext.instructions,
                messages: messages
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            reporter.report(error, context: "chat request")
            switch error {
            case ProviderFailure.invalidKey: throw ExperienceFailure.invalidKey(providerName: provider.name)
            case ProviderFailure.quotaOrRateLimit: throw ExperienceFailure.quotaOrRateLimit(providerName: provider.name)
            case ProviderFailure.rejectedRequest: throw ExperienceFailure.providerConfiguration(providerName: provider.name)
            case ProviderFailure.connection: throw ExperienceFailure.network
            case ProviderFailure.unusableReply: throw ExperienceFailure.unusableReply
            default: throw ExperienceFailure.serviceUnavailable
            }
        }
    }
}
