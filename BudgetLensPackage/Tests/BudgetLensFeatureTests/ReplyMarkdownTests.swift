import Foundation
import Testing
@testable import BudgetLensFeature

struct ReplyMarkdownTests {
    @Test func emphasisIsStyledAndMarkersAreRemoved() {
        let rendered = ReplyMarkdown.render("A **steady** month")

        #expect(String(rendered.characters) == "A steady month")
        #expect(rendered.runs.contains { $0.inlinePresentationIntent == .stronglyEmphasized })
    }

    @Test func linksLoseTheirTarget() {
        let rendered = ReplyMarkdown.render("See [this site](https://example.com) now")

        #expect(String(rendered.characters) == "See this site now")
        #expect(rendered.runs.allSatisfy { $0.link == nil })
    }

    @Test func lineBreaksSurvive() {
        #expect(String(ReplyMarkdown.render("First\n\nSecond").characters) == "First\n\nSecond")
    }

    @Test func plainTextIsUnchanged() {
        let text = "Groceries and Dining Out are above plan."
        #expect(String(ReplyMarkdown.render(text).characters) == text)
    }
}
