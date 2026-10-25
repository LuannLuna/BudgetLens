import SwiftUI

struct ChatMessageRow: View {
    let message: ChatMessage
    let providerName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutSpace.small) {
            if message.role == .user {
                Text("You", comment: "Chat message sender: the user")
                    .font(.caption.bold())
            } else if let providerName {
                Text("BudgetLens · \(providerName)", comment: "Chat message sender with assistant provider name")
                    .font(.caption.bold())
            } else {
                Text("BudgetLens", comment: "Chat message sender: the assistant")
                    .font(.caption.bold())
            }
            content
                .textSelection(.enabled)
                .privacySensitive()
        }
        .padding(LayoutSpace.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: LayoutSpace.medium))
        .accessibilityElement(children: .combine)
    }

    /// Your own text is shown as typed; the assistant's reply gets inline Markdown styling.
    @ViewBuilder
    private var content: some View {
        if message.role == .assistant {
            Text(ReplyMarkdown.render(message.text))
        } else {
            Text(verbatim: message.text)
        }
    }
}
