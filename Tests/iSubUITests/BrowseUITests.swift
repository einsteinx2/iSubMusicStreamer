//
//  BrowseUITests.swift
//  iSubUITests
//
//  Created by Benjamin Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// E2E-02 Library Browse page: quick albums + load-more, shuffle all (all folders +
// specific folder), now playing tap-to-play and swipe-to-queue, and the server chat row
// that only appears once the Enable Server Chat setting is on. Runs against the embedded
// mock HTTP server so playback flows behave like production.
final class BrowseUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = ISubApp.launch(mockServer: true)
        app.waitForTabBar()
        return app
    }

    private func openBrowse(in app: XCUIApplication) {
        app.openTab(AccessibilityId.tabLibrary)
        let browseTab = app.buttons["Browse"].firstMatch
        XCTAssertTrue(browseTab.waitForExistence(timeout: 10), "no Browse page button in Library")
        browseTab.tap()
        XCTAssertTrue(app.cells[AccessibilityId.browseRecentlyAdded].waitForExistence(timeout: 10),
                      "Browse page rows did not appear")
    }

    private func tapBrowseRow(_ identifier: String, in app: XCUIApplication,
                              file: StaticString = #filePath, line: UInt = #line) {
        let row = app.cells[identifier].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "no browse row '\(identifier)'", file: file, line: line)
        XCTAssertTrue(pollUntil(timeout: 10) { row.isHittable }, "browse row '\(identifier)' is not tappable", file: file, line: line)
        row.tap()
    }

    func testQuickAlbumsAndLoadMore() {
        let app = launch()
        openBrowse(in: app)
        tapBrowseRow(AccessibilityId.browseRecentlyAdded, in: app)

        XCTAssertTrue(app.navigationBars["Recently Added"].waitForExistence(timeout: 10),
                      "recently added list did not open")

        // The fixture returns 21 albums (>= the page size), so a loading row appears at the end
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15), "quick albums list did not load")
        let initialCount = app.cells.count
        XCTAssertGreaterThanOrEqual(initialCount, 20)

        // Rendering the trailing loading row triggers the next page load, which appends rows
        let table = app.tables.firstMatch
        let loadingCell = app.staticTexts["Loading more results..."]
        for _ in 0..<15 {
            if loadingCell.exists || app.cells.count > initialCount { break }
            table.swipeUp()
        }
        waitUntil { app.cells.count > initialCount }
        XCTAssertGreaterThan(app.cells.count, initialCount, "no rows appended after the load-more row appeared")
    }

    func testShuffleAllFolders() {
        let app = launch()
        openBrowse(in: app)
        tapBrowseRow(AccessibilityId.browseShuffleAll, in: app)

        // With multiple media folders cached a folder-picker sheet appears first
        let allFolders = app.sheets.buttons["All Media Folders"]
        if allFolders.waitForExistence(timeout: 2) {
            allFolders.tap()
        }
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 30),
                      "shuffle all did not land on the player")

        // The play queue was filled with the 10 fixture songs
        app.openTab(AccessibilityId.tabPlaylists)
        let countLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] '10 song'")).firstMatch
        XCTAssertTrue(countLabel.waitForExistence(timeout: 10), "server shuffle did not queue the fixture songs")
    }

    func testShuffleSpecificFolder() {
        let app = launch()

        // Load the library first so the media folders are cached and the picker appears
        app.openTab(AccessibilityId.tabLibrary)
        XCTAssertTrue(app.cells.staticTexts["Beck"].waitForExistence(timeout: 15))

        openBrowse(in: app)
        tapBrowseRow(AccessibilityId.browseShuffleAll, in: app)
        let musicFolder = app.sheets.buttons["Music"]
        XCTAssertTrue(musicFolder.waitForExistence(timeout: 10), "media folder picker did not appear")
        musicFolder.tap()

        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 30),
                      "folder shuffle did not land on the player")
    }

    func testNowPlayingTapToPlayAndSwipeToQueue() {
        let app = launch()
        openBrowse(in: app)
        tapBrowseRow(AccessibilityId.browseNowPlaying, in: app)
        XCTAssertTrue(app.navigationBars["Now Playing"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15), "now playing list did not load")

        // Swipe to queue records a banner confirmation
        app.firstCellText.swipeLeft()
        let queueButton = app.buttons["Queue"].firstMatch
        XCTAssertTrue(queueButton.waitForExistence(timeout: 5), "no Queue swipe action")
        queueButton.tap()

        // Tap to play opens the player
        app.tapFirstCellText()
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 15),
                      "tapping a now-playing row did not open the player")
    }

    func testChatHiddenUntilEnabledThenPostAndReload() {
        let app = launch()

        // Chat is off by default, so the Browse page has no chat row
        openBrowse(in: app)
        XCTAssertFalse(app.cells[AccessibilityId.browseChat].exists,
                       "chat row is visible without the setting enabled")

        // Enable Server Chat in Appearance & Behavior
        app.openTab(AccessibilityId.tabHome)
        app.buttons[AccessibilityId.homeSettings].tap()
        if !app.navigationBars["Settings"].waitForExistence(timeout: 5) {
            app.buttons[AccessibilityId.homeSettings].tap()
        }
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        app.buttons["settings.section.appearanceBehavior"].tap()
        XCTAssertTrue(app.navigationBars["Appearance & Behavior"].waitForExistence(timeout: 10))
        app.tapToggle(AccessibilityId.optionsEnableServerChat)

        // Settings screens hide the tab bar, so pop back out before switching tabs
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.tabBars.buttons[AccessibilityId.tabLibrary].waitForExistence(timeout: 10),
                      "tab bar did not reappear after leaving settings")

        // The chat row appears on the Browse page now
        openBrowse(in: app)
        tapBrowseRow(AccessibilityId.browseChat, in: app)

        // The fixture returns existing messages (the keyboard may cover part of the list)
        XCTAssertTrue(app.navigationBars["Chat"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15), "chat messages did not load")

        let textInput = app.textViews[AccessibilityId.chatTextInput]
        textInput.tap()
        textInput.typeText("hello from the UI tests")
        app.buttons[AccessibilityId.chatSend].tap()

        // The message posts (stubbed OK) and the list reloads; the input is cleared
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15))
        let value = textInput.value as? String ?? ""
        XCTAssertTrue(value.isEmpty, "chat input was not cleared after sending")
    }
}
