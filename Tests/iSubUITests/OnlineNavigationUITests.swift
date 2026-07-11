//
//  OnlineNavigationUITests.swift
//  iSubUITests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// E2E-02 cross-tab navigation: every tab shows its root screen (the automatic player
// presentation after starting playback is covered per-screen in the other suites).
final class OnlineNavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testTabNavigationShowsEachRootScreen() {
        let app = ISubApp.launch(mockServer: true)
        app.waitForTabBar()

        app.openTab(AccessibilityId.tabLibrary)
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 10))

        app.openTab(AccessibilityId.tabPlaylists)
        XCTAssertTrue(app.navigationBars["Playlists"].waitForExistence(timeout: 10))

        app.openTab(AccessibilityId.tabPlayer)
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 10))

        app.openTab(AccessibilityId.tabDownloads)
        XCTAssertTrue(app.navigationBars["Downloads"].waitForExistence(timeout: 10))

        app.openTab(AccessibilityId.tabSettings)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
    }
}
