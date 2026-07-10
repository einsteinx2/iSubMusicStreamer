//
//  OnlineDownloadsUITests.swift
//  iSubUITests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// E2E-02 Downloads tab: browse all sub-tabs after seeding downloads through the mock
// HTTP server, play cached content, download-queue management including deleting the
// active download (-SLOWDOWNLOAD keeps the transfer in-flight), and deletion flows.
final class OnlineDownloadsUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    // Downloads the two fixture songs (MP3 + FLAC) via the album swipe action and waits
    // for them to land in the Songs sub-tab
    private func launchWithDownloads() -> XCUIApplication {
        let app = ISubApp.launch(mockServer: true)
        app.waitForTabBar()
        app.drillToFixtureSongs()
        app.swipeAction("Download", onCellContaining: "MP3 Song")
        app.swipeAction("Download", onCellContaining: "FLAC Tone")
        app.triggerDownloadQueueStart()

        app.openTab(AccessibilityId.tabDownloads)
        app.buttons["Songs"].firstMatch.tap()
        XCTAssertTrue(app.cells.staticTexts["MP3 Song"].waitForExistence(timeout: 60),
                      "downloaded MP3 did not appear in the Songs sub-tab")
        XCTAssertTrue(app.cells.staticTexts["FLAC Tone"].waitForExistence(timeout: 60),
                      "downloaded FLAC did not appear in the Songs sub-tab")
        return app
    }

    func testBrowseAllSubTabsAndPlayCachedContent() {
        let app = launchWithDownloads()

        // Folders sub-tab shows the downloaded folder hierarchy
        app.buttons["Folders"].firstMatch.tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15), "Folders sub-tab is empty")

        // Artists and Albums sub-tabs show the tag metadata of the downloads
        app.buttons["Artists"].firstMatch.tap()
        XCTAssertTrue(app.cells.staticTexts["Test Tones"].waitForExistence(timeout: 15),
                      "Artists sub-tab missing the downloaded artist")
        app.buttons["Albums"].firstMatch.tap()
        XCTAssertTrue(app.cells.staticTexts["Formats"].waitForExistence(timeout: 15),
                      "Albums sub-tab missing the downloaded album")

        // The download queue is empty after both transfers finished
        app.buttons["Download Queue"].firstMatch.tap()
        XCTAssertTrue(waitUntil(timeout: 15) { app.cells.count == 0 }, "download queue is not empty")

        // Playing a downloaded song (FLAC exercises the BASS plugin path) opens the player
        app.buttons["Songs"].firstMatch.tap()
        app.tapCell(containing: "FLAC Tone")
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 15),
                      "playing a downloaded song did not open the player")
    }

    func testDeleteDownloadedSongViaSwipeAndSelectAll() {
        let app = launchWithDownloads()

        // Swipe-delete one song (deleted rows can linger in the accessibility tree,
        // so assert on hittability)
        app.swipeAction("Delete", onCellContaining: "MP3 Song")
        XCTAssertTrue(waitUntil(timeout: 15) { !app.cells.staticTexts["MP3 Song"].isHittable },
                      "swipe delete did not remove the downloaded song")

        // Select-all delete clears the rest
        app.buttons[AccessibilityId.saveEditHeaderEdit].firstMatch.tap()
        app.buttons[AccessibilityId.saveEditHeaderSaveDelete].firstMatch.tap() // selects all
        app.buttons[AccessibilityId.saveEditHeaderSaveDelete].firstMatch.tap() // deletes
        XCTAssertTrue(waitUntil(timeout: 20) { !app.cells.staticTexts["FLAC Tone"].isHittable },
                      "select-all delete did not clear the downloaded songs")
    }

    func testDeleteActiveDownloadFromQueue() {
        // Slow downloads keep the first transfer in-flight while we manipulate the queue
        let app = ISubApp.launch(mockServer: true, slowDownload: true)
        app.waitForTabBar()
        app.drillToFixtureSongs()
        app.swipeAction("Download", onCellContaining: "MP3 Song")
        app.swipeAction("Download", onCellContaining: "FLAC Tone")
        app.triggerDownloadQueueStart()

        app.openTab(AccessibilityId.tabDownloads)
        app.buttons["Download Queue"].firstMatch.tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 20), "download queue is empty")

        // Delete the first (active) download while its bytes are still trickling in
        let firstRow = app.cells.element(boundBy: 0)
        let rowCount = app.cells.count
        firstRow.swipeLeft()
        let deleteButton = app.buttons["Delete"].firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "no Delete swipe action in the queue")
        deleteButton.tap()

        XCTAssertTrue(waitUntil(timeout: 20) { app.cells.count < rowCount },
                      "deleting the active download did not remove it from the queue")

        // The app survives and the remaining download continues/completes
        app.buttons["Songs"].firstMatch.tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 90),
                      "remaining queued download never completed after deleting the active one")
    }
}
