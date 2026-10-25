import Testing
@testable import BudgetLensFeature

struct ExperienceFailureTests {
    static let retryable: [ExperienceFailure] = [
        .network, .unusableReply, .serviceUnavailable, .quotaOrRateLimit(providerName: "Test")
    ]
    static let settingsFixes: [ExperienceFailure] = [
        .missingKey, .invalidKey(providerName: "Test"), .providerConfiguration(providerName: "Test"),
        .keyStorage, .invalidProvider
    ]
    static let noAskAction: [ExperienceFailure] = [
        .snapshotUnavailable, .providerStorage, .invalidProviderDetails(.emptyName)
    ]

    @Test(arguments: ExperienceFailureTests.retryable)
    func retryableFailuresOfferRetryOnly(_ failure: ExperienceFailure) {
        #expect(failure.canRetryQuestion)
        #expect(failure.needsSettings == false)
    }

    @Test(arguments: ExperienceFailureTests.settingsFixes)
    func settingsFailuresOpenSettingsWithoutRetry(_ failure: ExperienceFailure) {
        #expect(failure.canRetryQuestion == false)
        #expect(failure.needsSettings)
    }

    @Test(arguments: ExperienceFailureTests.noAskAction)
    func otherFailuresOfferNoAskAction(_ failure: ExperienceFailure) {
        #expect(failure.canRetryQuestion == false)
        #expect(failure.needsSettings == false)
    }
}
