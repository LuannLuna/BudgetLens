import SwiftUI

struct KeyEditorSheet: View {
    let provider: Provider
    let onSave: (String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var failure: ExperienceFailure?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(String(localized: "API key", comment: "Key editor field label"), text: $draft)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .privacySensitive()
                        .accessibilityIdentifier("keyEditorField")
                    Button(String(localized: "Save key", comment: "Persist the entered API key"), systemImage: "key") { save() }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("keyEditorSave")
                } header: {
                    Text(verbatim: provider.name)
                } footer: {
                    Text("Asking a question sends the relevant historical budget snapshot to \(provider.name).", comment: "Key editor provider disclosure")
                }

                if let failure {
                    Section { FailureNoticeView(failure: failure) }
                }
            }
            .navigationTitle(Text("API key", comment: "Key editor screen title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Cancel", comment: "Close the key editor without saving"), systemImage: "xmark") { dismiss() }
                }
            }
        }
    }

    private func save() {
        do {
            try onSave(draft)
            dismiss()
        } catch let error as ExperienceFailure {
            failure = error
        } catch {
            failure = .keyStorage
        }
    }
}
