import Foundation
import Testing
@testable import BudgetLensFeature

struct OpenAICompatibleChatClientTests {
    @Test func parsesFirstChoiceContent() throws {
        let data = Data(#"{"choices":[{"message":{"content":"  Savings is on track.  "}}]}"#.utf8)
        #expect(try OpenAICompatibleChatClient.parseReply(data) == "Savings is on track.")
    }

    @Test(arguments: [
        #"{"choices":[]}"#,
        #"{"choices":[{"message":{"content":null}}]}"#,
        #"{"choices":[{"message":{"content":"  "}}]}"#,
        "not JSON"
    ])
    func unusableResponseIsRejected(_ value: String) {
        do {
            _ = try OpenAICompatibleChatClient.parseReply(Data(value.utf8))
            Issue.record("Expected an unusable reply error")
        } catch ProviderFailure.unusableReply {
            // Correctly classified as a response-content failure.
        } catch {
            Issue.record("Unexpected response error: \(type(of: error))")
        }
    }
}
