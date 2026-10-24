import Foundation

enum SnapshotLoadFailure: Error {
    case missingResource
}

struct BundledSnapshotLoader {
    let bundle: Bundle

    init(bundle: Bundle = .module) {
        self.bundle = bundle
    }

    func load() throws -> Data {
        guard let url = bundle.url(forResource: "BudgetLensSampleJSON", withExtension: "json") else {
            throw SnapshotLoadFailure.missingResource
        }
        return try Data(contentsOf: url)
    }
}
