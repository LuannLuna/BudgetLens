import Foundation

struct ChatMessage: Identifiable, Sendable {
    enum Role: Sendable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let text: String

    init(role: Role, text: String, id: UUID = UUID()) {
        self.id = id
        self.role = role
        self.text = text
    }
}
