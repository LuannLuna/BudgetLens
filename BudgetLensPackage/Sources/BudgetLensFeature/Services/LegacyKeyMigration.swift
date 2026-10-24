enum LegacyKeyMigration {
    enum Action: Equatable {
        case none
        case copy(value: String)
    }

    static func plan(newKey: String?, legacyKey: String?) -> Action {
        if let newKey, newKey.isEmpty == false { return .none }
        if let legacyKey, legacyKey.isEmpty == false { return .copy(value: legacyKey) }
        return .none
    }
}
