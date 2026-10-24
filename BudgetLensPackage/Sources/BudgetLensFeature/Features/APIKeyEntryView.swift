import SwiftUI

struct APIKeyEntryView: View {
    let access: BudgetAccessState
    @State private var draft = ""
    @State private var failure: ExperienceFailure?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(String(localized: "OpenAI API key", comment: "Secure key entry field label"), text: $draft)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .privacySensitive()
                        .accessibilityIdentifier("apiKeyField")
                    Button(String(localized: "Continue", comment: "Save key and open budget"), systemImage: "arrow.right") { save() }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("continueButton")
                } header: {
                    Text("Connect your AI assistant", comment: "First-launch key entry heading")
                } footer: {
                    Text("Your key is stored in this device's Keychain. Asking a question sends the relevant historical budget snapshot to OpenAI.", comment: "Key storage and third-party data disclosure")
                }

                if let failure {
                    Section {
                        FailureNoticeView(failure: failure)
                    }
                }
            }
            .navigationTitle(Text("Welcome to BudgetLens", comment: "Onboarding title"))
        }
    }

    private func save() {
        do {
            try access.saveKey(draft)
            draft = ""
            failure = nil
        } catch let error as ExperienceFailure {
            failure = error
        } catch {
            access.experience.reporter.report(error, context: "key entry")
            failure = .keyStorage
        }
    }
}
