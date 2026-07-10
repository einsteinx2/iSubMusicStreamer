//
//  SmokeUITests.swift
//  iSubUITests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// Smoke tests: one per launch mode, asserting the app boots to its root UI against the
// in-app fixture stub with no real network. See docs/UI_TESTING.md for the launch
// argument contract.
final class SmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    private func launchApp(mode: String? = nil, fixtures: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITEST", "-RESET_STATE"]
        if let mode = mode {
            app.launchArguments += ["-MODE", mode]
        }
        if let fixtures = fixtures {
            app.launchArguments += ["-FIXTURES", fixtures]
        }
        app.launch()
        return app
    }

    private func assertRootUI(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.tabBars.buttons[AccessibilityId.tabHome].waitForExistence(timeout: 30),
                      "app did not reach the root tab bar", file: file, line: line)
        for tab in [AccessibilityId.tabLibrary, AccessibilityId.tabPlayer, AccessibilityId.tabPlaylists, AccessibilityId.tabDownloads] {
            XCTAssertTrue(app.tabBars.buttons[tab].exists, "missing tab \(tab)", file: file, line: line)
        }
    }

    func testOnlineModeReachesRootUI() {
        let app = launchApp()
        assertRootUI(in: app)

        // With a seeded server the app must not route to first-run server setup
        XCTAssertFalse(app.textFields[AccessibilityId.serverEditURL].exists)
    }

    func testOfflineModeReachesRootUI() {
        let app = launchApp(mode: "offline")
        assertRootUI(in: app)
    }

    func testMockServerModeReachesRootUI() {
        // -MOCKSERVER serves fixtures over real loopback HTTP instead of the URLProtocol stub
        let app = XCUIApplication()
        app.launchArguments += ["-UITEST", "-RESET_STATE", "-MOCKSERVER"]
        app.launch()
        assertRootUI(in: app)
    }

    func testJukeboxModeReachesRootUI() {
        let app = launchApp(mode: "jukebox")
        assertRootUI(in: app)

        // The player tab is reachable in jukebox mode
        app.tabBars.buttons[AccessibilityId.tabPlayer].tap()
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 10))
    }
}
