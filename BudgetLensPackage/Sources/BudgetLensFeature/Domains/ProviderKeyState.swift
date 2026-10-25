struct ProviderKeyState: Identifiable, Equatable, Sendable {
    let provider: Provider
    let hasKey: Bool

    var id: String { provider.id }
}
