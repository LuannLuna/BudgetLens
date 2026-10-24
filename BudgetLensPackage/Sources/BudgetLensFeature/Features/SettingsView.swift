import SwiftUI

struct SettingsView: View {
    let access: BudgetAccessState
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var failure: ExperienceFailure?
    @State private var confirmingClear = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(String(localized: "New OpenAI API key", comment: "Replace saved key field label"), text: $draft)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .privacySensitive()
                    Button(String(localized: "Replace API key", comment: "Save a new API key"), systemImage: "key") { replace() }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } footer: {
                    Text("Your existing key is never shown. Replacing it starts a new in-memory chat.", comment: "Key replacement and chat privacy note")
                }

                Section {
                    Button(String(localized: "Clear API key", comment: "Start key removal confirmation"), systemImage: "trash", role: .destructive) {
                        confirmingClear = true
                    }
                }

                if let failure {
                    Section { FailureNoticeView(failure: failure) }
                }
            }
            .navigationTitle(Text("Settings", comment: "Key management screen title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done", comment: "Close key management"), systemImage: "checkmark") { dismiss() }
                }
            }
            .confirmationDialog(
                String(localized: "Remove your saved API key?", comment: "Key removal confirmation title"),
                isPresented: $confirmingClear,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Clear API key", comment: "Confirm saved key removal"), role: .destructive) { clear() }
            } message: {
                Text("You'll return to the key entry screen. This also ends the current chat.", comment: "Confirmation for key removal")
            }
        }
    }

    private func replace() {
        do {
            try access.saveKey(draft)
            draft = ""
            failure = nil
            dismiss()
        } catch let error as ExperienceFailure {
            failure = error
        } catch {
            access.experience.reporter.report(error, context: "key replacement")
            failure = .keyStorage
        }
    }

    private func clear() {
        do {
            try access.clearKey()
            draft = ""
            failure = nil
            dismiss()
        } catch let error as ExperienceFailure {
            failure = error
        } catch {
            access.experience.reporter.report(error, context: "key removal")
            failure = .keyStorage
        }
    }
}
