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

    @MainActor
    func testAddingCustomAssistantOnWelcomeConnectsIt() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-reset"]
        app.launch()

        let keyField = app.secureTextFields["apiKeyField"]
        XCTAssertTrue(keyField.waitForExistence(timeout: 5))

        app.buttons["providerPicker"].tap()
        let customOption = app.buttons["Custom assistant…"]
        XCTAssertTrue(customOption.waitForExistence(timeout: 3))
        customOption.tap()

        let nameField = app.textFields["customNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Local Test")
        let urlField = app.textFields["customURLField"]
        urlField.tap()
        urlField.typeText("https://example.com/v1")
        let modelField = app.textFields["customModelField"]
        modelField.tap()
        modelField.typeText("test-model")
        app.buttons["customSaveButton"].tap()

        let picker = app.buttons["providerPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3))
        XCTAssertTrue(picker.label.contains("Local Test"))

        keyField.tap()
        keyField.typeText("test-only-custom-key")
        app.buttons["continueButton"].tap()

        XCTAssertTrue(app.tabBars.buttons["Budget"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["connectionBanner"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Ask"].tap()
        XCTAssertTrue(app.staticTexts["Answering with Local Test"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testReturningToAssistantWithSavedKeyReusesIt() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-reset"]
        app.launch()

        let keyField = app.secureTextFields["apiKeyField"]
        XCTAssertTrue(keyField.waitForExistence(timeout: 5))
        keyField.tap()
        keyField.typeText("test-only-sample-key")
        app.buttons["continueButton"].tap()
        XCTAssertTrue(app.tabBars.buttons["Budget"].waitForExistence(timeout: 5))

        // Switching to an assistant without a key opens key entry again.
        app.buttons["Settings"].tap()
        app.buttons["activeAssistantPicker"].tap()
        app.buttons["Gemini"].tap()
        XCTAssertTrue(keyField.waitForExistence(timeout: 5))

        // Picking the assistant that already has a key lets Continue work with an empty field.
        app.buttons["providerPicker"].tap()
        app.buttons["OpenAI"].tap()
        XCTAssertTrue(app.buttons["continueButton"].isEnabled)
        app.buttons["continueButton"].tap()
        XCTAssertTrue(app.tabBars.buttons["Budget"].waitForExistence(timeout: 5))
    }
}
