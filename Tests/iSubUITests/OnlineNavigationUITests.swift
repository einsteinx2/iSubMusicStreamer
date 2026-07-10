//
//  OnlineNavigationUITests.swift
//  iSubUITests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// E2E-02 cross-tab navigation and every player-open affordance: the player tab itself,
// the Home song-info button, and the automatic player presentation after starting
// playback from other screens (covered per-screen in the other suites).
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

        app.openTab(AccessibilityId.tabPlayer)
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 10))

        app.openTab(AccessibilityId.tabPlaylists)
        XCTAssertTrue(app.navigationBars["Playlists"].waitForExistence(timeout: 10))

        app.openTab(AccessibilityId.tabDownloads)
        XCTAssertTrue(app.navigationBars["Downloads"].waitForExistence(timeout: 10))

        app.openTab(AccessibilityId.tabHome)
        XCTAssertTrue(app.buttons[AccessibilityId.homeQuickAlbums].waitForExistence(timeout: 10))
    }

    func testHomeSongInfoButtonOpensPlayer() {
        let app = ISubApp.launch(mockServer: true)
        app.waitForTabBar()

        // Start playback, then return Home; the song-info button shows the current song
        app.startPlaybackViaServerShuffle()
        app.openTab(AccessibilityId.tabHome)

        let songInfo = app.buttons[AccessibilityId.homeSongInfo]
        XCTAssertTrue(songInfo.waitForExistence(timeout: 10), "home song info button missing")
        songInfo.tap()
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 10),
                      "song info button did not open the player")
    }

}
