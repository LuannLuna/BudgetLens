import SwiftUI

struct MainExperienceView: View {
    let snapshot: BudgetSnapshot
    let access: BudgetAccessState
    @State private var showingSettings = false

    var body: some View {
        TabView {
            NavigationStack {
                BudgetView(snapshot: snapshot)
                    .navigationTitle(Text("Budget", comment: "Budget tab navigation title"))
                    .toolbar { settingsToolbar }
            }
            .tabItem { Label(String(localized: "Budget", comment: "Budget tab label"), systemImage: "chart.bar.xaxis") }

            NavigationStack {
                AskView(snapshot: snapshot, experience: access.experience, openSettings: { showingSettings = true })
                    .id(access.keyRevision)
                    .navigationTitle(Text("Ask", comment: "Chat tab navigation title"))
                    .toolbar { settingsToolbar }
            }
            .tabItem { Label(String(localized: "Ask", comment: "Assistant chat tab label"), systemImage: "bubble.left.and.bubble.right") }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(access: access)
        }
    }

    @ToolbarContentBuilder
    private var settingsToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(String(localized: "Settings", comment: "Open API key management"), systemImage: "gearshape") { showingSettings = true }
        }
    }
}
