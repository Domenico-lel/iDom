import XCTest

final class PersonalToolsUITests: XCTestCase {
    private let app = XCUIApplication()
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()
    }
    func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func openTool(_ name: String) {
        app.tabBars.buttons["Tools"].tap()
        let tool = app.staticTexts[name].firstMatch
        XCTAssertTrue(tool.waitForExistence(timeout: 10))
        tool.tap()
    }
    func testPCRemoteRequiresPairingBeforePowerCommands() {
        openTool("PC Remote")
        XCTAssertTrue(app.buttons["pc.configure"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Spegni"].exists)
        capture("PC Remote · collegamento")
        app.buttons["pc.configure"].tap()
        XCTAssertFalse(app.buttons["Salva"].isEnabled)
        app.textFields["Indirizzo HTTPS Tailscale"].tap()
        app.textFields["Indirizzo HTTPS Tailscale"].typeText("http://example.org")
        XCTAssertFalse(app.buttons["Salva"].isEnabled)
        app.buttons["Annulla"].tap()
        XCTAssertTrue(app.buttons["pc.configure"].waitForExistence(timeout: 5))
    }
    func testQuickCopyPersistsEditsAndDeletes() {
        openTool("Quick Copy")
        app.buttons["Aggiungi testo"].tap()
        let name = "Testo " + UUID().uuidString.prefix(6)
        app.textFields["copy.title"].tap()
        app.textFields["copy.title"].typeText(String(name))
        let value = app.textViews["copy.value"].exists ? app.textViews["copy.value"] : app.textFields["copy.value"]
        value.tap()
        value.typeText("Prima riga | email@example.com")
        app.buttons["Salva"].tap()
        let row = app.buttons["Copia \(name)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        capture("Quick Copy")
        row.tap()
        XCTAssertEqual(row.value as? String, "Copiato")
        app.terminate()
        app.launch()
        openTool("Quick Copy")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["Modifica"].firstMatch.tap()
        let title = app.textFields["copy.title"]
        title.tap()
        title.typeText(" aggiornato")
        app.buttons["Salva"].tap()
        let updated = app.buttons["Copia \(name) aggiornato"]
        XCTAssertTrue(updated.waitForExistence(timeout: 5))
        updated.swipeLeft()
        app.buttons["Elimina"].firstMatch.tap()
        app.alerts.buttons["Elimina"].tap()
        XCTAssertFalse(updated.exists)
    }
    func testSpendValidationAndPersistence() {
        openTool("Spend")
        app.buttons["Aggiungi spesa"].tap()
        let title = "Spesa " + UUID().uuidString.prefix(6)
        app.textFields["expense.title"].tap()
        app.textFields["expense.title"].typeText(String(title))
        XCTAssertFalse(app.buttons["Salva"].isEnabled)
        app.textFields["expense.amount"].tap()
        app.textFields["expense.amount"].typeText("12,50")
        XCTAssertTrue(app.buttons["Salva"].isEnabled)
        app.buttons["Salva"].tap()
        XCTAssertTrue(app.staticTexts[String(title)].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        openTool("Spend")
        let row = app.staticTexts[String(title)]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        capture("Modifica spesa")
        XCTAssertEqual(app.textFields["expense.amount"].value as? String, "12,50")
        app.buttons["Annulla"].tap()
        row.swipeLeft()
        app.buttons["Elimina"].firstMatch.tap()
        app.alerts.buttons["Elimina"].tap()
        XCTAssertFalse(row.exists)
    }
    func testDeadlineAndParkingEmptyState() {
        openTool("Scadenze")
        app.buttons["Aggiungi scadenza"].tap()
        let title = "Scadenza " + UUID().uuidString.prefix(6)
        app.textFields["deadline.title"].tap()
        app.textFields["deadline.title"].typeText(String(title))
        app.buttons["Salva"].tap()
        let row = app.staticTexts[String(title)]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        capture("Modifica scadenza")
        app.switches["Completata"].tap()
        app.buttons["Salva"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["Elimina"].firstMatch.tap()
        app.alerts.buttons["Elimina"].tap()
        XCTAssertFalse(row.exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.staticTexts["Parcheggio"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Salva posizione attuale"].waitForExistence(timeout: 5))
        capture("Parcheggio")
    }
}
