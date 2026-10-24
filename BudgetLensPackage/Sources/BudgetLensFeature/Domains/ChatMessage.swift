import Foundation

struct ChatMessage: Identifiable, Sendable {
    enum Role: Sendable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let text: String
    let providerID: String?

    init(role: Role, text: String, providerID: String? = nil, id: UUID = UUID()) {
        self.id = id
        self.role = role
        self.text = text
        self.providerID = providerID
    }
}
