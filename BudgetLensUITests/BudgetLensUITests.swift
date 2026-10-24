import XCTest

final class BudgetLensUITests: XCTestCase {
    @MainActor
    func testKeyEntryBudgetAndReset() throws {
        let app = XCUIApplication()
        app.launch()
        let keyField = app.secureTextFields["apiKeyField"]
        if keyField.waitForExistence(timeout: 5) == false {
            app.buttons["Settings"].tap()
            app.buttons["Clear API key"].firstMatch.tap()
            let confirmation = app.buttons.matching(identifier: "Clear API key")
            confirmation.element(boundBy: confirmation.count - 1).tap()
        }

        XCTAssertTrue(keyField.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["continueButton"].isEnabled)
        keyField.tap()
        keyField.typeText("test-only-sample-key")
        app.buttons["continueButton"].tap()
        XCTAssertTrue(app.tabBars.buttons["Budget"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Worth reviewing"].exists)
        app.tabBars.buttons["Ask"].tap()
        XCTAssertFalse(app.buttons["sendButton"].isEnabled)

        app.buttons["Settings"].tap()
        let replacement = app.secureTextFields["New OpenAI API key"]
        replacement.tap()
        replacement.typeText("replacement-test-only-key")
        app.buttons["Replace API key"].tap()
        XCTAssertTrue(app.tabBars.buttons["Budget"].waitForExistence(timeout: 5))

        app.buttons["Settings"].tap()
        app.buttons["Clear API key"].firstMatch.tap()
        let confirmation = app.buttons.matching(identifier: "Clear API key")
        confirmation.element(boundBy: confirmation.count - 1).tap()
        XCTAssertTrue(keyField.waitForExistence(timeout: 5))
    }
}
