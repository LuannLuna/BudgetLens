import SwiftUI

@MainActor
struct BudgetLensRootView: View {
    let access: BudgetAccessState

    var body: some View {
        switch access.phase {
        case .loading:
            ProgressView {
                Text("Opening your snapshot", comment: "Loading the local budget snapshot")
            }
        case .needsKey(_, let providerID):
            APIKeyEntryView(access: access)
                .id(providerID)
        case .ready(let snapshot):
            MainExperienceView(snapshot: snapshot, access: access)
        case .failure(let failure):
            ContentUnavailableView {
                Label(String(localized: "We couldn't open your snapshot", comment: "Local snapshot loading failure title"), systemImage: "doc.text")
            } description: {
                FailureNoticeView(failure: failure)
            } actions: {
                Button(String(localized: "Try again", comment: "Retry opening the local snapshot"), systemImage: "arrow.clockwise") { access.retryPreparation() }
            }
        }
    }
}
