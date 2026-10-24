import Foundation
import Testing
@testable import BudgetLensFeature

struct ResponseClientTests {
    @Test func parsesAssistantOutputText() throws {
        let data = Data(#"{"status":"completed","output":[{"type":"message","role":"assistant","content":[{"type":"output_text","text":"  You have two categories over budget.  "}]}]}"#.utf8)
        #expect(try OpenAIResponseClient.parseReply(data) == "You have two categories over budget.")
    }

    @Test(arguments: [
        #"{"status":"completed","output":[]}"#,
        #"{"status":"incomplete","output":[{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Partial"}]}]}"#,
        #"{"status":"completed","output":[{"type":"message","role":"assistant","content":[{"type":"output_text","text":"  "}]}]}"#,
        "not JSON"
    ])
    func unusableResponseIsRejected(_ value: String) {
        do {
            _ = try OpenAIResponseClient.parseReply(Data(value.utf8))
            Issue.record("Expected an unusable reply error")
        } catch ProviderFailure.unusableReply {
            // Correctly classified as a response-content failure.
        } catch {
            Issue.record("Unexpected response error: \(type(of: error))")
        }
    }
}
