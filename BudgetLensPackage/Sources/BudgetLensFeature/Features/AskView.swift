import SwiftUI

struct AskView: View {
    let snapshot: BudgetSnapshot
    let access: BudgetAccessState
    let openSettings: () -> Void
    @State private var conversation: ChatConversationState

    init(snapshot: BudgetSnapshot, access: BudgetAccessState, openSettings: @escaping () -> Void) {
        self.snapshot = snapshot
        self.access = access
        self.openSettings = openSettings
        _conversation = State(initialValue: ChatConversationState(experience: access.experience))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: LayoutSpace.medium) {
                HStack {
                    Text("Answering with \(access.activeProviderName)", comment: "Active assistant indicator")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        ForEach(access.providers) { provider in
                            Button {
                                do {
                                    try access.setActiveProvider(provider.id)
                                } catch {
                                    // The access state reports the failure itself.
                                }
                            } label: {
                                if provider.id == access.activeProviderID {
                                    Label(provider.name, systemImage: "checkmark")
                                } else {
                                    Text(verbatim: provider.name)
                                }
                            }
                        }
                    } label: {
                        Label(String(localized: "Switch assistant", comment: "Switch the active assistant"), systemImage: "arrow.left.arrow.right")
                            .labelStyle(.iconOnly)
                            .accessibilityLabel(String(localized: "Switch assistant", comment: "Switch the active assistant"))
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }

                if conversation.messages.isEmpty {
                    Text("Let's look at your budget together", comment: "Supportive chat welcome heading")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("Ask about the \(BudgetText.period(snapshot.period)) snapshot. It's historical sample data, not a live balance.", comment: "Chat historical data notice")
                        .foregroundStyle(.secondary)
                    Button(overBudgetPrompt) {
                        Task { await conversation.useSuggestion(overBudgetPrompt, snapshot: snapshot) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    Button(overviewPrompt) {
                        Task { await conversation.useSuggestion(overviewPrompt, snapshot: snapshot) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                ForEach(conversation.messages) { message in
                    ChatMessageRow(message: message, providerName: access.providerName(for: message.providerID))
                }

                if conversation.isSending {
                    ProgressView {
                        Text("Thinking about your question", comment: "LLM request in progress")
                    }
                }
                if let failure = conversation.failure {
                    VStack(alignment: .leading, spacing: LayoutSpace.small) {
                        FailureNoticeView(failure: failure)
                        if failure.canRetryQuestion {
                            Button(String(localized: "Try again", comment: "Retry the failed chat question"), systemImage: "arrow.clockwise") {
                                Task { await conversation.retry(snapshot: snapshot) }
                            }
                            .frame(minHeight: 44)
                        } else if failure.needsSettings {
                            Button(String(localized: "Open Settings", comment: "Fix a key or assistant problem"), systemImage: "gearshape", action: openSettings)
                        }
                    }
                    .padding(LayoutSpace.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: LayoutSpace.medium))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(LayoutSpace.medium)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: LayoutSpace.small) {
                Text("Sending a question shares this snapshot and recent chat with \(access.activeProviderName). No currency is specified.", comment: "Disclosure immediately above chat composer")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(alignment: .bottom, spacing: LayoutSpace.small) {
                    TextField(String(localized: "Ask about your budget", comment: "Chat input placeholder"), text: $conversation.draft, axis: .vertical)
                        .lineLimit(1...3)
                        .accessibilityIdentifier("chatComposer")
                    Button(String(localized: "Send", comment: "Submit a budget question to the assistant"), systemImage: "arrow.up") {
                        Task { await conversation.send(snapshot: snapshot) }
                    }
                    .disabled(conversation.isSending || conversation.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("sendButton")
                }
            }
            .padding(LayoutSpace.medium)
            .background(Color(.secondarySystemGroupedBackground))
        }
    }

    private var overBudgetPrompt: String {
        String(localized: "Which categories are over budget?", comment: "Suggested chat question about over-budget categories")
    }

    private var overviewPrompt: String {
        String(localized: "What stands out in this snapshot?", comment: "Suggested chat question about a budget overview")
    }
}
