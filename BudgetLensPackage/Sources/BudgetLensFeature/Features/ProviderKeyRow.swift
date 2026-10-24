import SwiftUI

struct ProviderKeyRow: View {
    let state: ProviderKeyState
    let replace: () -> Void
    let clear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutSpace.small) {
            HStack(alignment: .firstTextBaseline, spacing: LayoutSpace.small) {
                Text(verbatim: state.provider.name)
                    .font(.headline)
                Spacer()
                statusLabel
            }
            Text(verbatim: state.provider.model)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: LayoutSpace.medium) {
                Button(String(localized: "Replace key", comment: "Replace a saved API key"), systemImage: "key") { replace() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier("replaceKey.\(state.provider.id)")
                if state.hasKey {
                    Button(String(localized: "Clear key", comment: "Start key removal confirmation"), systemImage: "trash", role: .destructive) { clear() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("clearKey.\(state.provider.id)")
                }
            }
        }
        .padding(.vertical, LayoutSpace.small)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusLabel: some View {
        Label(
            state.hasKey
                ? String(localized: "Key saved", comment: "Key storage status")
                : String(localized: "No key", comment: "Key storage status"),
            systemImage: state.hasKey ? "checkmark.circle.fill" : "circle.dashed"
        )
        .font(.caption)
        .foregroundStyle(state.hasKey ? Color.green : Color.secondary)
    }
}
