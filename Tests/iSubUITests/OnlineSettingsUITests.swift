//
//  OnlineSettingsUITests.swift
//  iSubUITests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// E2E-02 Settings: options toggles + persistence across relaunch, and server management
// (add/edit/delete/switch) in the SwiftUI settings hierarchy: a root list of sections
// (Servers, Network & Streaming, ..., About) instead of the old Servers/Options
// segmented control. Runs against the URLProtocol fixture stub so any server URL
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

    // Opens a settings section screen from the root list by its row identifier
    private func openSection(_ rowId: String, title: String, in app: XCUIApplication) {
        openSettings(in: app)
        app.buttons[rowId].tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10),
                      "section '\(title)' did not open")
    }

    private func openServers(in app: XCUIApplication) {
        openSection(AccessibilityId.settingsSectionServers, title: "Servers", in: app)
    }

    private func switchValue(_ app: XCUIApplication, _ identifier: String) -> String {
        (app.switches[identifier].firstMatch.value as? String) ?? ""
    }

    private func toggle(_ app: XCUIApplication, _ identifier: String) {
        let control = app.switches[identifier].firstMatch
        if !control.isHittable {
            app.swipeUp()
        }
        control.tap()
    }

    func testOptionsTogglesPersistAcrossRelaunch() {
        var app = launch()

        // Flip a toggle in Playback (scrobbling) and pick a new quick skip length
        openSection("settings.section.playback", title: "Playback", in: app)
        let scrobbleBefore = switchValue(app, AccessibilityId.optionsEnableScrobbling)
        toggle(app, AccessibilityId.optionsEnableScrobbling)
        XCTAssertNotEqual(switchValue(app, AccessibilityId.optionsEnableScrobbling), scrobbleBefore)
        let scrobbleAfter = switchValue(app, AccessibilityId.optionsEnableScrobbling)

        // Quick skip is a menu picker now (30s -> 1 minute)
        let quickSkip = app.buttons[AccessibilityId.optionsQuickSkipSegment].firstMatch
        XCTAssertTrue(quickSkip.waitForExistence(timeout: 10), "quick skip picker missing")
        quickSkip.tap()
        app.buttons["1 minute"].firstMatch.tap()

        // And a toggle in Appearance & Behavior (popups, now positively phrased)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        app.buttons["settings.section.appearanceBehavior"].tap()
        XCTAssertTrue(app.navigationBars["Appearance & Behavior"].waitForExistence(timeout: 10))
        let popupsBefore = switchValue(app, AccessibilityId.optionsShowPopups)
        toggle(app, AccessibilityId.optionsShowPopups)
        XCTAssertNotEqual(switchValue(app, AccessibilityId.optionsShowPopups), popupsBefore)
        let popupsAfter = switchValue(app, AccessibilityId.optionsShowPopups)

        // Relaunch without resetting state; the values must persist
        app.terminate()
        app = launch(resetState: false)
        openSection("settings.section.playback", title: "Playback", in: app)
        XCTAssertEqual(switchValue(app, AccessibilityId.optionsEnableScrobbling), scrobbleAfter,
                       "scrobble setting did not persist")
        let persistedQuickSkip = app.buttons[AccessibilityId.optionsQuickSkipSegment].firstMatch
        XCTAssertTrue(persistedQuickSkip.waitForExistence(timeout: 10))
        XCTAssertTrue(persistedQuickSkip.label.contains("1 minute"),
                      "quick skip setting did not persist (label: \(persistedQuickSkip.label))")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        app.buttons["settings.section.appearanceBehavior"].tap()
        XCTAssertTrue(app.navigationBars["Appearance & Behavior"].waitForExistence(timeout: 10))
        XCTAssertEqual(switchValue(app, AccessibilityId.optionsShowPopups), popupsAfter,
                       "popups setting did not persist")
    }

    func testDeletingCurrentOnlyServerShowsAddServer() {
        let app = launch()
        openServers(in: app)

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10), "servers list is empty")
        app.cells.firstMatch.swipeLeft()
        let deleteButton = app.buttons["Delete"].firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "no Delete swipe action on server row")
        deleteButton.tap()

        // With no servers left the add-server form appears automatically (STUB-08)
        XCTAssertTrue(app.textFields[AccessibilityId.serverEditURL].waitForExistence(timeout: 10),
                      "deleting the only server must present the add-server screen")
    }

    func testServersAddEditDeleteSwitch() {
        let app = launch()
        openServers(in: app)

        // The seeded server is listed
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10), "servers list is empty")
        XCTAssertEqual(app.cells.count, 1)

        // Add: the + toolbar button opens the form, which saves against the stub
        app.buttons[AccessibilityId.serversAdd].tap()
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
        XCTAssertEqual(app.cells.count, 2)

        // Edit: the row's info button opens the form; changing the username persists
        // (the old ServerEditViewController silently discarded field edits — fixed)
        let secondRow = app.cell(containing: "http://second.server.local")
        secondRow.buttons[AccessibilityId.serversEdit].tap()
        XCTAssertTrue(urlField.waitForExistence(timeout: 10))
        usernameField.tap()
        usernameField.typeText("-renamed")
        app.buttons[AccessibilityId.serverEditSave].tap()
        XCTAssertTrue(app.tabBars.buttons[AccessibilityId.tabHome].waitForExistence(timeout: 20))
        openServers(in: app)
        XCTAssertTrue(app.cells.staticTexts["username: seconduser-renamed"].waitForExistence(timeout: 10),
                      "edited username not shown")

        // Switch: tapping the first (seeded) server verifies and switches to it
        app.tapCell(containing: "http://uitest.local")
        XCTAssertTrue(app.tabBars.buttons[AccessibilityId.tabHome].waitForExistence(timeout: 20),
                      "switching servers did not return to the app")

        // Delete: swipe-delete the second server
        openServers(in: app)
        let secondRowText = app.cells.staticTexts["http://second.server.local"]
        XCTAssertTrue(secondRowText.waitForExistence(timeout: 10))
        secondRowText.swipeLeft()
        let deleteButton = app.buttons["Delete"].firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "no Delete swipe action on server row")
        deleteButton.tap()
        XCTAssertTrue(waitUntil(timeout: 10) { app.cells.count == 1 }, "server was not deleted")

        // Reorder is part of the manual QA spec but the servers list has no reorder
        // support yet; this documents the gap and flips when it lands
        XCTExpectFailure("Server list reordering not implemented yet", strict: false) {
            app.buttons["Edit"].firstMatch.tap()
            let reorderControl = app.cells.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder'")).firstMatch
            XCTAssertTrue(reorderControl.waitForExistence(timeout: 3), "no reorder controls on the servers list")
        }
    }
}
