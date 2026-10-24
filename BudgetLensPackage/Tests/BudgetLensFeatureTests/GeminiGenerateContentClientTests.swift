import Foundation
import Testing
@testable import BudgetLensFeature

struct GeminiGenerateContentClientTests {
    @Test func parsesCandidateParts() throws {
        let data = Data(#"{"candidates":[{"content":{"parts":[{"text":"  Two categories are over budget.  "}]}}]}"#.utf8)
        #expect(try GeminiGenerateContentClient.parseReply(data) == "Two categories are over budget.")
    }

    @Test(arguments: [
        #"{"candidates":[]}"#,
        #"{"candidates":[{"content":{"parts":[]}}]}"#,
        #"{"candidates":[{"content":{"parts":[{"text":"  "}]}}]}"#,
        "not JSON"
    ])
    func unusableResponseIsRejected(_ value: String) {
        do {
            _ = try GeminiGenerateContentClient.parseReply(Data(value.utf8))
            Issue.record("Expected an unusable reply error")
        } catch ProviderFailure.unusableReply {
            // Correctly classified as a response-content failure.
        } catch {
            Issue.record("Unexpected response error: \(type(of: error))")
        }
    }
}
