import Foundation
import Observation

@MainActor @Observable
final class ChatConversationState {
    var draft = ""
    private(set) var messages: [ChatMessage] = []
    private(set) var isSending = false
    private(set) var failure: ExperienceFailure?
    private var pendingQuestion: String?
    let experience: BudgetExperience

    init(experience: BudgetExperience) {
        self.experience = experience
    }

    func send(snapshot: BudgetSnapshot) async {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard question.isEmpty == false, isSending == false else { return }
        if pendingQuestion != nil {
            messages.removeLast()
            pendingQuestion = nil
        }
        draft = ""
        messages.append(ChatMessage(role: .user, text: question))
        pendingQuestion = question
        await requestReply(snapshot: snapshot, providerID: experience.activeProviderID)
    }

    func useSuggestion(_ question: String, snapshot: BudgetSnapshot) async {
        draft = question
        await send(snapshot: snapshot)
    }

    func retry(snapshot: BudgetSnapshot) async {
        guard pendingQuestion != nil, isSending == false else { return }
        await requestReply(snapshot: snapshot, providerID: experience.activeProviderID)
    }

    private func requestReply(snapshot: BudgetSnapshot, providerID: String) async {
        guard let question = pendingQuestion else { return }
        isSending = true
        failure = nil
        defer { isSending = false }
        do {
            let history = Array(messages.dropLast())
            let reply = try await experience.ask(question, history: history, snapshot: snapshot)
            messages.append(ChatMessage(role: .assistant, text: reply, providerID: providerID))
            pendingQuestion = nil
        } catch is CancellationError {
            // Cancellation is an expected result when a request is abandoned.
        } catch let error as ExperienceFailure {
            fail(with: error)
        } catch {
            experience.report(error, context: "chat state")
            fail(with: .serviceUnavailable)
        }
    }

    /// A failure that cannot be retried in place (a key or assistant fix in Settings) hands the question back to the composer.
    private func fail(with error: ExperienceFailure) {
        failure = error
        guard error.canRetryQuestion == false, let question = pendingQuestion else { return }
        messages.removeLast()
        pendingQuestion = nil
        draft = [question, draft].filter { $0.isEmpty == false }.joined(separator: "\n")
    }
}
