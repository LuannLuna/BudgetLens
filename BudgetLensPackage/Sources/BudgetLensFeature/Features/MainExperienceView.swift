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
                AskView(snapshot: snapshot, access: access, openSettings: { showingSettings = true })
                    .id(access.keyRevision)
                    .navigationTitle(Text("Ask", comment: "Chat tab navigation title"))
                    .toolbar { settingsToolbar }
            }
            .tabItem { Label(String(localized: "Ask", comment: "Assistant chat tab label"), systemImage: "bubble.left.and.bubble.right") }
        }
        .overlay(alignment: .top) {
            if let name = access.justConnectedProviderName {
                Label {
                    Text("Connected to \(name)", comment: "Connection confirmation banner naming the assistant")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                    .font(.subheadline.bold())
                    .padding(.horizontal, LayoutSpace.medium)
                    .padding(.vertical, LayoutSpace.small)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, LayoutSpace.small)
                    .task(id: name) {
                        do {
                            try await Task.sleep(for: .seconds(3))
                        } catch {
                            return
                        }
                        access.dismissConnectionNotice()
                    }
                    .accessibilityIdentifier("connectionBanner")
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(access: access)
        }
    }

    @ToolbarContentBuilder
    private var settingsToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(String(localized: "Settings", comment: "Open assistant and key management"), systemImage: "gearshape") { showingSettings = true }
        }
    }
}
