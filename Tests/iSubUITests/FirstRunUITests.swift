//
//  FirstRunUITests.swift
//  iSubUITests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// E2E-01: Launch + first-run server setup. Launches with -FIRSTRUN (network stubbed, no
// seeded server) so the app routes through the real first-run flow: SceneDelegate pushes
// Settings, ServersViewController auto-presents the server-edit form. Fully offline —
// ping responses come from the fixture stub (-FIXTURES badauth for the failure flow).
final class FirstRunUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    private func launchFirstRun(fixtures: String = "default", resetState: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITEST", "-FIRSTRUN", "-FIXTURES", fixtures]
        if resetState {
            app.launchArguments += ["-RESET_STATE"]
        }
        app.launch()
        return app
    }

    // The server-edit form auto-presents only when the store contains zero servers
    // (ServersViewController.viewWillAppear), so its appearance doubles as an assertion
    // that no server entry is persisted.
    @discardableResult
    private func waitForServerSetup(in app: XCUIApplication, timeout: TimeInterval = 30,
                                    file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let urlField = app.textFields[AccessibilityId.serverEditURL]
        XCTAssertTrue(urlField.waitForExistence(timeout: timeout),
                      "first run did not route to the server setup form", file: file, line: line)
        return urlField
    }

    private func enterCredentials(in app: XCUIApplication, url: String = "http://uitest.local",
                                  username: String = "uitest", password: String = "uitest") {
        let urlField = app.textFields[AccessibilityId.serverEditURL]
        urlField.tap()
        urlField.typeText(url)

        let usernameField = app.textFields[AccessibilityId.serverEditUsername]
        usernameField.tap()
        usernameField.typeText(username)

        let passwordField = app.secureTextFields[AccessibilityId.serverEditPassword]
        passwordField.tap()
        passwordField.typeText(password)
    }

    // MARK: Tests

    func testFirstRunRoutesToServerSetup() {
        let app = launchFirstRun()
        waitForServerSetup(in: app)

        // The full form is present
        XCTAssertTrue(app.textFields[AccessibilityId.serverEditUsername].exists)
        XCTAssertTrue(app.secureTextFields[AccessibilityId.serverEditPassword].exists)
        XCTAssertTrue(app.buttons[AccessibilityId.serverEditSave].exists)

        // And the app did not silently land on the main UI behind it
        XCTAssertFalse(app.tabBars.buttons[AccessibilityId.tabHome].isHittable)
    }

    func testValidCredentialsLandOnMainTabBar() {
        let app = launchFirstRun()
        waitForServerSetup(in: app)

        enterCredentials(in: app)
        app.buttons[AccessibilityId.serverEditSave].tap()

        // Stubbed ping success: the form dismisses and the main tab bar appears
        let homeTab = app.tabBars.buttons[AccessibilityId.tabHome]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 30), "valid credentials did not land on the main tab bar")
        XCTAssertFalse(app.textFields[AccessibilityId.serverEditURL].exists)

        // The server persisted: a relaunch (no state reset) goes straight to the main UI
        app.terminate()
        let relaunched = launchFirstRun(resetState: false)
        XCTAssertTrue(relaunched.tabBars.buttons[AccessibilityId.tabHome].waitForExistence(timeout: 30),
                      "server did not persist across relaunch")
        XCTAssertFalse(relaunched.textFields[AccessibilityId.serverEditURL].exists)
    }

    // BUG-17 regression: a failed auth on first-ever server add must not persist a server entry
    func testFailedAuthPersistsNoServerEntry() {
        let app = launchFirstRun(fixtures: "badauth")
        waitForServerSetup(in: app)

        enterCredentials(in: app, password: "wrongpassword")
        app.buttons[AccessibilityId.serverEditSave].tap()

        // The bad-credentials alert appears; the form stays up
        let alert = app.alerts["Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: 30), "failed auth did not show an error alert")
        alert.buttons["OK"].tap()
        XCTAssertTrue(app.textFields[AccessibilityId.serverEditURL].exists)

        // Behind the form, the servers table must contain no entry
        app.buttons[AccessibilityId.serverEditClose].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.tables.cells.count, 0, "failed auth persisted a server entry (BUG-17)")

        // And a relaunch (no state reset) must route to first-run setup again — the
        // auto-presented form asserts the store still has zero servers
        app.terminate()
        let relaunched = launchFirstRun(fixtures: "badauth", resetState: false)
        waitForServerSetup(in: relaunched)
    }

    // BUG-17 regression: correcting the credentials after a failed first add must end
    // with exactly one server entry, never a duplicate
    func testRetryAfterFailedAuthCreatesSingleEntry() {
        // First attempt fails against the badauth fixtures
        let app = launchFirstRun(fixtures: "badauth")
        waitForServerSetup(in: app)
        enterCredentials(in: app, password: "wrongpassword")
        app.buttons[AccessibilityId.serverEditSave].tap()
        let alert = app.alerts["Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: 30), "failed auth did not show an error alert")
        alert.buttons["OK"].tap()
        app.terminate()

        // Relaunch (no state reset) with working fixtures and retry with good credentials
        let relaunched = launchFirstRun(resetState: false)
        waitForServerSetup(in: relaunched)
        enterCredentials(in: relaunched)
        relaunched.buttons[AccessibilityId.serverEditSave].tap()
        XCTAssertTrue(relaunched.tabBars.buttons[AccessibilityId.tabHome].waitForExistence(timeout: 30),
                      "valid credentials did not land on the main tab bar")

        // The servers list (Settings root) must contain exactly one entry
        let settingsButton = relaunched.buttons[AccessibilityId.homeSettings]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10), "home settings button missing")
        settingsButton.tap()
        if !relaunched.navigationBars["Settings"].waitForExistence(timeout: 5) {
            // The home screen occasionally swallows the first tap right after launch
            settingsButton.tap()
        }
        XCTAssertTrue(relaunched.navigationBars["Settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(relaunched.tables.cells.firstMatch.waitForExistence(timeout: 10), "servers list is empty")
        XCTAssertEqual(relaunched.tables.cells.count, 1, "the retry must not create a duplicate server entry")
    }
}
