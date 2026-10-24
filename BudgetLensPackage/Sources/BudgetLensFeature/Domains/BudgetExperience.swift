import Foundation

@MainActor
struct BudgetExperience {
    let snapshotLoader: BundledSnapshotLoader
    let keyStore: any APIKeyStoring
    let client: any LLMResponding
    let reporter: any ErrorReporting

    init(
        snapshotLoader: BundledSnapshotLoader = BundledSnapshotLoader(),
        keyStore: any APIKeyStoring = KeychainAPIKeyStore(),
        client: any LLMResponding = OpenAIResponseClient(),
        reporter: any ErrorReporting = SafeErrorReporter()
    ) {
        self.snapshotLoader = snapshotLoader
        self.keyStore = keyStore
        self.client = client
        self.reporter = reporter
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

    func hasKey() throws -> Bool {
        do {
            return try keyStore.read()?.isEmpty == false
        } catch {
            reporter.report(error, context: "key reading")
            throw ExperienceFailure.keyStorage
        }
    }

    func saveKey(_ input: String) throws {
        let key = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.isEmpty == false else { throw ExperienceFailure.missingKey }
        do {
            try keyStore.save(key)
        } catch {
            reporter.report(error, context: "key saving")
            throw ExperienceFailure.keyStorage
        }
    }

    func clearKey() throws {
        do {
            try keyStore.clear()
        } catch {
            reporter.report(error, context: "key clearing")
            throw ExperienceFailure.keyStorage
        }
    }

    func ask(_ question: String, history: [ChatMessage], snapshot: BudgetSnapshot) async throws -> String {
        let key: String
        do {
            guard let saved = try keyStore.read(), saved.isEmpty == false else {
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
            return try await client.respond(key: key, instructions: BudgetContext.instructions, messages: messages)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            reporter.report(error, context: "chat request")
            switch error {
            case ProviderFailure.invalidKey: throw ExperienceFailure.invalidKey
            case ProviderFailure.connection: throw ExperienceFailure.network
            case ProviderFailure.unusableReply: throw ExperienceFailure.unusableReply
            default: throw ExperienceFailure.serviceUnavailable
            }
        }
    }
}
