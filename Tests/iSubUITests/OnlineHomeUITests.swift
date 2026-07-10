//
//  OnlineHomeUITests.swift
//  iSubUITests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// E2E-02 Home tab: quick albums + load-more, server shuffle (all folders + specific
// folder), search (all + result playback), chat post/reload, now playing tap-to-play and
// swipe-to-queue, jukebox toggle UI state. Runs against the embedded mock HTTP server so
// playback flows behave like production.
final class OnlineHomeUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = ISubApp.launch(mockServer: true)
        app.waitForTabBar()
        return app
    }

    func testQuickAlbumsAndLoadMore() {
        let app = launch()
        app.buttons[AccessibilityId.homeQuickAlbums].tap()

        let recentlyAdded = app.sheets.buttons["Recently Added"]
        XCTAssertTrue(recentlyAdded.waitForExistence(timeout: 10), "quick albums action sheet did not appear")
        recentlyAdded.tap()

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

    func testServerShuffleAllFolders() {
        let app = launch()
        app.startPlaybackViaServerShuffle()

        // The play queue was filled with the 10 fixture songs
        app.openTab(AccessibilityId.tabPlaylists)
        let countLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] '10 song'")).firstMatch
        XCTAssertTrue(countLabel.waitForExistence(timeout: 10), "server shuffle did not queue the fixture songs")
    }

    func testServerShuffleSpecificFolder() {
        let app = launch()

        // Load the library first so the media folders are cached and the picker appears
        app.openTab(AccessibilityId.tabLibrary)
        XCTAssertTrue(app.cells.staticTexts["Beck"].waitForExistence(timeout: 15))

        app.openTab(AccessibilityId.tabHome)
        app.buttons[AccessibilityId.homeServerShuffle].tap()
        let musicFolder = app.sheets.buttons["Music"]
        XCTAssertTrue(musicFolder.waitForExistence(timeout: 10), "media folder picker did not appear")
        musicFolder.tap()

        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 30),
                      "folder shuffle did not land on the player")
    }

    func testSearchAllSectionsAndResultPlayback() {
        let app = launch()

        let searchBar = app.otherElements[AccessibilityId.homeSearchBar].firstMatch
        let searchField = searchBar.exists ? searchBar : app.searchFields.firstMatch
        searchField.tap()
        app.typeText("beck\n")

        // The results screen has one sub-tab per section (Artists / Albums / Songs)
        XCTAssertTrue(app.cells.staticTexts["Beck"].waitForExistence(timeout: 15),
                      "search results did not load an artist section")
        app.buttons["Albums"].firstMatch.tap()
        XCTAssertTrue(app.cells.staticTexts["Disc 1"].waitForExistence(timeout: 10), "no album section result")
        app.buttons["Songs"].firstMatch.tap()

        // Playing a song result must open the player. This currently fails silently:
        // the search loaders never persist their songs to the store, so playing a search
        // result can't resolve the queued song and does nothing.
        app.tapCell(containing: "Novacane")
        XCTExpectFailure("BUG: search results are not persisted to the store, so playing one silently fails", strict: false) {
            XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 15),
                          "tapping a search result song did not open the player")
        }
    }

    func testChatPostAndReload() {
        let app = launch()
        app.buttons[AccessibilityId.homeChat].tap()

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

    func testNowPlayingTapToPlayAndSwipeToQueue() {
        let app = launch()
        app.buttons[AccessibilityId.homeNowPlaying].tap()
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

    func testJukeboxToggleUIState() {
        let app = launch()

        XCTAssertTrue(app.staticTexts["Jukebox\nMode is OFF"].exists)
        app.buttons[AccessibilityId.homeJukebox].tap()
        XCTAssertTrue(app.staticTexts["Jukebox\nMode is ON"].waitForExistence(timeout: 10),
                      "jukebox button did not switch to ON")

        app.buttons[AccessibilityId.homeJukebox].tap()
        XCTAssertTrue(app.staticTexts["Jukebox\nMode is OFF"].waitForExistence(timeout: 10),
                      "jukebox button did not switch back to OFF")
    }
}
