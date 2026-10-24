import SwiftUI

struct FailureNoticeView: View {
    let failure: ExperienceFailure

    var body: some View {
        Group {
            switch failure {
            case .missingKey:
                Text("Add an API key for this assistant to ask questions about the snapshot.", comment: "Missing API key recovery")
            case .invalidKey(let providerName):
                Text("\(providerName) couldn't accept that key. You can replace it in Settings and try again.", comment: "Invalid API key recovery")
            case .network:
                Text("We couldn't reach the assistant. Check your connection and try again.", comment: "Network failure recovery")
            case .unusableReply:
                Text("The assistant didn't return a usable answer. Please try again.", comment: "Empty or malformed LLM reply recovery")
            case .serviceUnavailable:
                Text("The assistant isn't available right now. Please try again later.", comment: "LLM provider error recovery")
            case .snapshotUnavailable:
                Text("The sample budget couldn't be read. Please try reopening the app.", comment: "Bundled snapshot loading failure")
            case .keyStorage:
                Text("We couldn't access the saved key on this device. Please try again.", comment: "Keychain failure recovery")
            case .invalidProvider:
                Text("That assistant isn't available anymore. Please choose another in Settings.", comment: "Unknown assistant recovery")
            case .invalidProviderDetails(let message):
                Text(verbatim: message)
            }
        }
        .foregroundStyle(.secondary)
    }
}
