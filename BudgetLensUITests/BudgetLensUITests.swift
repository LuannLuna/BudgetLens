import XCTest

final class BudgetLensUITests: XCTestCase {
    @MainActor
    func testKeyEntryBudgetAndReset() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-reset"]
        app.launch()

        let keyField = app.secureTextFields["apiKeyField"]
        XCTAssertTrue(keyField.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["continueButton"].isEnabled)
        keyField.tap()
        keyField.typeText("test-only-sample-key")
        app.buttons["continueButton"].tap()

        XCTAssertTrue(app.tabBars.buttons["Budget"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Worth reviewing"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["connectionBanner"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Ask"].tap()
        XCTAssertFalse(app.buttons["sendButton"].isEnabled)

        app.buttons["Settings"].tap()
        app.buttons["replaceKey.openai"].tap()
        let replacement = app.secureTextFields["keyEditorField"]
        replacement.tap()
        replacement.typeText("replacement-test-only-key")
        app.buttons["keyEditorSave"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.tabBars.buttons["Budget"].waitForExistence(timeout: 5))

        app.buttons["Settings"].tap()
        app.buttons["clearKey.openai"].tap()
        let confirm = app.buttons["Remove key"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(keyField.waitForExistence(timeout: 5))
    }

    @MainActor
    func testSelectingAnotherAssistantOnWelcomeConnectsIt() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-reset"]
        app.launch()

        let keyField = app.secureTextFields["apiKeyField"]
        XCTAssertTrue(keyField.waitForExistence(timeout: 5))

        app.buttons["providerPicker"].tap()
        let deepSeek = app.buttons["DeepSeek"]
        XCTAssertTrue(deepSeek.waitForExistence(timeout: 3))
        deepSeek.tap()

        keyField.tap()
        keyField.typeText("test-only-deepseek-key")
        app.buttons["continueButton"].tap()

        XCTAssertTrue(app.tabBars.buttons["Budget"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["connectionBanner"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Ask"].tap()
        XCTAssertTrue(app.staticTexts["Answering with DeepSeek"].waitForExistence(timeout: 3))
    }
}
