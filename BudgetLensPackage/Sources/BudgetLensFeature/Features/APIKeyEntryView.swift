import SwiftUI

struct APIKeyEntryView: View {
    private static let customOptionID = "__custom_assistant__"

    let access: BudgetAccessState
    @State private var selectedProviderID: String
    @State private var draft = ""
    @State private var failure: ExperienceFailure?
    @State private var showingCustomEditor = false

    init(access: BudgetAccessState) {
        self.access = access
        _selectedProviderID = State(initialValue: access.needsKeyProviderID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String(localized: "Assistant", comment: "Provider selection on key entry"), selection: $selectedProviderID) {
                        ForEach(access.providers) { provider in
                            Text(verbatim: provider.name).tag(provider.id)
                        }
                        Text("Custom assistant…", comment: "Option to add a custom OpenAI-compatible assistant")
                            .tag(Self.customOptionID)
                    }
                    .accessibilityIdentifier("providerPicker")
                    .onChange(of: selectedProviderID) { oldValue, newValue in
                        guard newValue == Self.customOptionID else { return }
                        selectedProviderID = oldValue
                        showingCustomEditor = true
                    }
                    SecureField(String(localized: "API key", comment: "Secure key entry field label"), text: $draft)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .privacySensitive()
                        .accessibilityIdentifier("apiKeyField")
                    Button(String(localized: "Continue", comment: "Save key and open budget"), systemImage: "arrow.right") { connect() }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("continueButton")

                    if let failure {
                        FailureNoticeView(failure: failure)
                            .accessibilityIdentifier("keyEntryFailure")
                    }
                } header: {
                    Text("Connect your AI assistant", comment: "First-launch key entry heading")
                } footer: {
                    Text("Continue stores the key in this device's Keychain and opens your budget as \(selectedProviderName). No request is sent yet: \(selectedProviderName) checks the key when you ask your first question. Asking a question shares the relevant historical budget snapshot with \(selectedProviderName). Choose Custom assistant… to use any OpenAI-compatible endpoint.", comment: "Key storage, no-API-call clarification, third-party data disclosure, and custom assistant hint")
                }
            }
            .navigationTitle(Text("Welcome to BudgetLens", comment: "Onboarding title"))
            .sheet(isPresented: $showingCustomEditor) {
                CustomProviderEditorSheet { name, baseURL, model in
                    let provider = try access.addCustomProvider(name: name, baseURL: baseURL, model: model)
                    selectedProviderID = provider.id
                }
            }
        }
    }

    private var selectedProviderName: String {
        access.providerName(for: selectedProviderID) ?? selectedProviderID
    }

    private func connect() {
        do {
            try access.connect(draft, providerID: selectedProviderID)
            draft = ""
            failure = nil
        } catch let error as ExperienceFailure {
            failure = error
        } catch {
            access.experience.report(error, context: "key entry")
            failure = .keyStorage
        }
    }
}
