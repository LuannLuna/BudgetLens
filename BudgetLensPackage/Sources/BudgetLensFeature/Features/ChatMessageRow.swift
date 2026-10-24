import SwiftUI

struct ChatMessageRow: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutSpace.small) {
            if message.role == .user {
                Text("You", comment: "Chat message sender: the user")
                    .font(.caption.bold())
            } else {
                Text("BudgetLens", comment: "Chat message sender: the assistant")
                    .font(.caption.bold())
            }
            Text(verbatim: message.text)
                .textSelection(.enabled)
                .privacySensitive()
        }
        .padding(LayoutSpace.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: LayoutSpace.medium))
        .accessibilityElement(children: .combine)
    }
}
