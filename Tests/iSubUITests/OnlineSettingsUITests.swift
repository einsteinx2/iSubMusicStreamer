//
//  OnlineSettingsUITests.swift
//  iSubUITests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// E2E-02 Settings: options toggles + persistence across relaunch, and server management
// (add/edit/delete/switch). Runs against the URLProtocol fixture stub so any server URL
// entered in the edit form is intercepted and answered with fixture XML.
final class OnlineSettingsUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    private func launch(resetState: Bool = true) -> XCUIApplication {
        let app = ISubApp.launch(resetState: resetState)
        app.waitForTabBar()
        return app
    }

    private func openSettings(in app: XCUIApplication) {
        app.openTab(AccessibilityId.tabHome)
        app.buttons[AccessibilityId.homeSettings].tap()
        if !app.navigationBars["Settings"].waitForExistence(timeout: 5) {
            // The tap can get swallowed during the initial layout; try once more
            app.buttons[AccessibilityId.homeSettings].tap()
        }
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
    }

    private func openOptions(in app: XCUIApplication) {
        openSettings(in: app)
        app.segmentedControls.buttons["Options"].tap()
        // The options screen ignores control changes made within 0.5s of loading
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1))
    }

    private func openServers(in app: XCUIApplication) {
        openSettings(in: app)
        app.segmentedControls.buttons["Servers"].tap()
    }

    private func switchValue(_ app: XCUIApplication, _ identifier: String) -> String {
        (app.switches[identifier].value as? String) ?? ""
    }

    private func toggle(_ app: XCUIApplication, _ identifier: String) {
        let control = app.switches[identifier]
        if !control.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        control.tap()
    }

    func testOptionsTogglesPersistAcrossRelaunch() {
        var app = launch()
        openOptions(in: app)

        // Flip a few representative options
        let scrobbleBefore = switchValue(app, AccessibilityId.optionsEnableScrobbling)
        let popupsBefore = switchValue(app, AccessibilityId.optionsDisablePopups)
        toggle(app, AccessibilityId.optionsEnableScrobbling)
        toggle(app, AccessibilityId.optionsDisablePopups)
        XCTAssertNotEqual(switchValue(app, AccessibilityId.optionsEnableScrobbling), scrobbleBefore)
        XCTAssertNotEqual(switchValue(app, AccessibilityId.optionsDisablePopups), popupsBefore)
        let scrobbleAfter = switchValue(app, AccessibilityId.optionsEnableScrobbling)
        let popupsAfter = switchValue(app, AccessibilityId.optionsDisablePopups)

        // And a segmented option (quick skip 30s -> 60s)
        let quickSkip = app.segmentedControls[AccessibilityId.optionsQuickSkipSegment]
        if !quickSkip.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        quickSkip.buttons["1m"].tap()

        // Relaunch without resetting state; the values must persist
        app.terminate()
        app = launch(resetState: false)
        openOptions(in: app)
        XCTAssertEqual(switchValue(app, AccessibilityId.optionsEnableScrobbling), scrobbleAfter,
                       "scrobble setting did not persist")
        XCTAssertEqual(switchValue(app, AccessibilityId.optionsDisablePopups), popupsAfter,
                       "popups setting did not persist")
        let persistedQuickSkip = app.segmentedControls[AccessibilityId.optionsQuickSkipSegment]
        if !persistedQuickSkip.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(persistedQuickSkip.buttons["1m"].isSelected, "quick skip setting did not persist")
    }

    func testServersAddEditDeleteSwitch() {
        let app = launch()
        openServers(in: app)

        // The seeded server is listed
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10), "servers list is empty")
        XCTAssertEqual(app.tables.cells.count, 1)

        // Add: edit mode exposes the add (+) button, the form saves against the stub
        app.navigationBars.buttons["Edit"].tap()
        app.navigationBars.buttons["Add"].tap()
        let urlField = app.textFields[AccessibilityId.serverEditURL]
        XCTAssertTrue(urlField.waitForExistence(timeout: 10), "server edit form did not open")
        urlField.tap()
        urlField.typeText("http://second.server.local")
        let usernameField = app.textFields[AccessibilityId.serverEditUsername]
        usernameField.tap()
        usernameField.typeText("seconduser")
        let passwordField = app.secureTextFields[AccessibilityId.serverEditPassword]
        passwordField.tap()
        passwordField.typeText("secondpass")
        app.buttons[AccessibilityId.serverEditSave].tap()

        // Saving a new server switches to it and returns to the app; go back to the list
        XCTAssertTrue(app.tabBars.buttons[AccessibilityId.tabHome].waitForExistence(timeout: 20))
        openServers(in: app)
        XCTAssertTrue(app.cells.staticTexts["http://second.server.local"].waitForExistence(timeout: 10),
                      "added server not listed")
        XCTAssertEqual(app.tables.cells.count, 2)

        // Edit: change the username and save. The edit form validates the NEW credentials
        // but persists the original server object, so field edits are silently discarded —
        // a real bug this documents until the fix lands.
        app.navigationBars.buttons["Edit"].tap()
        app.tapCell(containing: "http://second.server.local")
        XCTAssertTrue(urlField.waitForExistence(timeout: 10))
        usernameField.tap()
        usernameField.typeText("-renamed")
        app.buttons[AccessibilityId.serverEditSave].tap()
        XCTAssertTrue(app.tabBars.buttons[AccessibilityId.tabHome].waitForExistence(timeout: 20))
        openServers(in: app)
        XCTExpectFailure("BUG: ServerEditViewController.checkServer saves the original serverToEdit, discarding edited fields", strict: false) {
            XCTAssertTrue(app.cells.staticTexts["username: seconduser-renamed"].waitForExistence(timeout: 10),
                          "edited username not shown")
        }

        // Switch: tapping the first (seeded) server verifies and switches to it
        app.tapCell(containing: "http://uitest.local")
        XCTAssertTrue(app.tabBars.buttons[AccessibilityId.tabHome].waitForExistence(timeout: 20),
                      "switching servers did not return to the app")

        // Delete: swipe-delete the second server
        openServers(in: app)
        let secondRow = app.cells.staticTexts["http://second.server.local"]
        XCTAssertTrue(secondRow.waitForExistence(timeout: 10))
        secondRow.swipeLeft()
        let deleteButton = app.buttons["Delete"].firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "no Delete swipe action on server row")
        deleteButton.tap()
        XCTAssertTrue(waitUntil(timeout: 10) { app.tables.cells.count == 1 }, "server was not deleted")

        // Reorder is part of the manual QA spec but the servers list has no reorder
        // support yet; this documents the gap and flips when it lands
        XCTExpectFailure("Server list reordering not implemented yet", strict: false) {
            app.navigationBars.buttons["Edit"].tap()
            let reorderControl = app.tables.cells.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder'")).firstMatch
            XCTAssertTrue(reorderControl.waitForExistence(timeout: 3), "no reorder controls on the servers list")
        }
    }
}
