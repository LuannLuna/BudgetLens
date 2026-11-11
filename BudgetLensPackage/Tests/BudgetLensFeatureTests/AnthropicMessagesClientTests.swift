import Foundation
import Testing
@testable import BudgetLensFeature

struct AnthropicMessagesClientTests {
    @Test func parsesTextContentBlocks() throws {
        let data = Data(#"{"content":[{"type":"text","text":"  Food market is over budget.  "}]}"#.utf8)
        #expect(try AnthropicMessagesClient.parseReply(data) == "Food market is over budget.")
    }

    @Test(arguments: [
        #"{"content":[]}"#,
        #"{"content":[{"type":"text","text":"  "}]}"#,
        #"{"content":[{"type":"thinking","text":"hidden"}]}"#,
        "not JSON"
    ])
    func unusableResponseIsRejected(_ value: String) {
        do {
            _ = try AnthropicMessagesClient.parseReply(Data(value.utf8))
            Issue.record("Expected an unusable reply error")
        } catch ProviderFailure.unusableReply {
            // Correctly classified as a response-content failure.
        } catch {
            Issue.record("Unexpected response error: \(type(of: error))")
        }
    }
}
