import Foundation
import Testing
@testable import BudgetLensFeature

struct ProviderStatusMappingTests {
    @Test(arguments: [
        (401, "", ProviderFailure.invalidKey),
        (403, "", ProviderFailure.invalidKey),
        (400, "API key not valid. Please pass a valid API key.", ProviderFailure.invalidKey),
        (400, "Incorrect Api Key provided", ProviderFailure.invalidKey),
        (400, "model is required", ProviderFailure.rejectedRequest),
        (400, "", ProviderFailure.rejectedRequest),
        (404, "", ProviderFailure.rejectedRequest),
        (422, "", ProviderFailure.rejectedRequest),
        (402, "", ProviderFailure.quotaOrRateLimit),
        (429, "", ProviderFailure.quotaOrRateLimit),
        (500, "", ProviderFailure.serviceUnavailable),
        (503, "", ProviderFailure.serviceUnavailable),
        (302, "", ProviderFailure.serviceUnavailable)
    ])
    func failureStatusesAreClassified(status: Int, body: String, expected: ProviderFailure) {
        #expect(ProviderStatusMapping.classify(status: status, body: Data(body.utf8)) == expected)
    }

    @Test(arguments: [200, 201, 204])
    func successStatusesAreNotFailures(status: Int) {
        #expect(ProviderStatusMapping.classify(status: status, body: Data()) == nil)
    }
}
