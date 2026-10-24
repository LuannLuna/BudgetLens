import SwiftUI

struct CustomProviderEditorSheet: View {
    let onSave: (String, String, String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var baseURL = ""
    @State private var model = ""
    @State private var failure: ExperienceFailure?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "Name", comment: "Custom assistant name field"), text: $name)
                        .accessibilityIdentifier("customNameField")
                    TextField(String(localized: "Base URL (https://…)", comment: "Custom assistant base URL field"), text: $baseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("customURLField")
                    TextField(String(localized: "Model", comment: "Custom assistant model field"), text: $model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("customModelField")
                    Button(String(localized: "Add assistant", comment: "Create the custom assistant"), systemImage: "plus") { save() }
                        .disabled(
                            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                        .accessibilityIdentifier("customSaveButton")
                } footer: {
                    Text("The endpoint must accept OpenAI-style chat completions at /chat/completions.", comment: "Custom assistant endpoint requirement")
                }

                if let failure {
                    Section { FailureNoticeView(failure: failure) }
                }
            }
            .navigationTitle(Text("Custom assistant", comment: "Custom assistant editor title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Cancel", comment: "Close the custom assistant editor"), systemImage: "xmark") { dismiss() }
                }
            }
        }
    }

    private func save() {
        do {
            try onSave(name, baseURL, model)
            dismiss()
        } catch let error as ExperienceFailure {
            failure = error
        } catch {
            failure = .keyStorage
        }
    }
}
