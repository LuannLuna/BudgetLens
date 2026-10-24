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
        await requestReply(snapshot: snapshot)
    }

    func useSuggestion(_ question: String, snapshot: BudgetSnapshot) async {
        draft = question
        await send(snapshot: snapshot)
    }

    func retry(snapshot: BudgetSnapshot) async {
        guard pendingQuestion != nil, isSending == false else { return }
        await requestReply(snapshot: snapshot)
    }

    private func requestReply(snapshot: BudgetSnapshot) async {
        guard let question = pendingQuestion else { return }
        isSending = true
        failure = nil
        defer { isSending = false }
        do {
            let history = Array(messages.dropLast())
            let reply = try await experience.ask(question, history: history, snapshot: snapshot)
            messages.append(ChatMessage(role: .assistant, text: reply))
            pendingQuestion = nil
        } catch is CancellationError {
            // Cancellation is an expected result when a request is abandoned.
        } catch let error as ExperienceFailure {
            failure = error
        } catch {
            experience.reporter.report(error, context: "chat state")
            failure = .serviceUnavailable
        }
    }
}
