import SwiftUI

struct SettingsView: View {
    let access: BudgetAccessState
    @Environment(\.dismiss) private var dismiss
    @State private var selection: String
    @State private var keyEditor: Provider?
    @State private var showingCustomEditor = false
    @State private var confirmingClear = false
    @State private var pendingClearProviderID: String?
    @State private var failure: ExperienceFailure?

    init(access: BudgetAccessState) {
        self.access = access
        _selection = State(initialValue: access.activeProviderID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String(localized: "Assistant", comment: "Active assistant selection"), selection: $selection) {
                        ForEach(access.providers) { provider in
                            Text(verbatim: provider.name).tag(provider.id)
                        }
                    }
                    .accessibilityIdentifier("activeAssistantPicker")
                    .onChange(of: selection) { _, newValue in
                        do {
                            try access.setActiveProvider(newValue)
                        } catch let error as ExperienceFailure {
                            failure = error
                        } catch {
                            access.experience.reporter.report(error, context: "assistant switching")
                            failure = .serviceUnavailable
                        }
                    }
                } footer: {
                    Text("Switching assistants keeps the current conversation. Choosing one without a key opens the key entry screen.", comment: "Assistant switching behavior note")
                }

                Section {
                    ForEach(access.keyStates) { state in
                        ProviderKeyRow(
                            state: state,
                            replace: { keyEditor = state.provider },
                            clear: { requestClear(state.provider) }
                        )
                    }
                } header: {
                    Text("Provider keys", comment: "Per-assistant key management heading")
                } footer: {
                    Text("Each assistant's key is stored separately in this device's Keychain.", comment: "Per-provider key storage note")
                }

                Section {
                    ForEach(access.keyStates.filter { $0.provider.isBuiltIn == false }) { state in
                        HStack {
                            VStack(alignment: .leading, spacing: LayoutSpace.small) {
                                Text(verbatim: state.provider.name).font(.headline)
                                Text(verbatim: state.provider.baseURL ?? "").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(String(localized: "Remove", comment: "Delete a custom assistant"), systemImage: "trash", role: .destructive) {
                                removeCustom(state.provider)
                            }
                            .accessibilityIdentifier("removeCustom.\(state.provider.id)")
                        }
                    }
                    Button(String(localized: "Add custom assistant", comment: "Create a custom OpenAI-compatible assistant"), systemImage: "plus") {
                        showingCustomEditor = true
                    }
                } header: {
                    Text("Custom assistants", comment: "Custom OpenAI-compatible assistants heading")
                } footer: {
                    Text("Use any OpenAI-compatible endpoint: a name, an https:// base URL, and a model. Removing an assistant also deletes its key.", comment: "Custom assistant usage note")
                }

                if let failure {
                    Section { FailureNoticeView(failure: failure) }
                }
            }
            .navigationTitle(Text("Settings", comment: "Assistant and key management screen title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done", comment: "Close settings"), systemImage: "checkmark") { dismiss() }
                }
            }
            .sheet(item: $keyEditor) { provider in
                KeyEditorSheet(provider: provider) { draft in
                    try access.saveKey(draft, providerID: provider.id)
                }
            }
            .sheet(isPresented: $showingCustomEditor) {
                CustomProviderEditorSheet { name, baseURL, model in
                    try access.addCustomProvider(name: name, baseURL: baseURL, model: model)
                }
            }
            .confirmationDialog(
                String(localized: "Remove this assistant's saved API key?", comment: "Key removal confirmation title"),
                isPresented: $confirmingClear,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Remove key", comment: "Confirm saved key removal"), role: .destructive) { clearPending() }
            } message: {
                Text("This assistant can't answer questions until you add a new key.", comment: "Confirmation for key removal")
            }
        }
    }

    private func requestClear(_ provider: Provider) {
        pendingClearProviderID = provider.id
        confirmingClear = true
    }

    private func clearPending() {
        guard let providerID = pendingClearProviderID else { return }
        do {
            try access.clearKey(providerID: providerID)
            pendingClearProviderID = nil
            failure = nil
        } catch let error as ExperienceFailure {
            failure = error
        } catch {
            access.experience.reporter.report(error, context: "key removal")
            failure = .keyStorage
        }
    }

    private func removeCustom(_ provider: Provider) {
        do {
            try access.removeCustomProvider(id: provider.id)
            failure = nil
        } catch let error as ExperienceFailure {
            failure = error
        } catch {
            access.experience.reporter.report(error, context: "custom assistant removal")
            failure = .keyStorage
        }
    }
}
