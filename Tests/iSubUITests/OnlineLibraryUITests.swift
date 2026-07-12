//
//  OnlineLibraryUITests.swift
//  iSubUITests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// E2E-02 Library tab: media-folder dropdown, folders/artists drill-down, play-all and
// shuffle at artist and album level, swipe-to-queue/cache, and bookmarks open/play/delete.
final class OnlineLibraryUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = ISubApp.launch(mockServer: true)
        app.waitForTabBar()
        return app
    }

    private func openFolders(in app: XCUIApplication) {
        app.openTab(AccessibilityId.tabLibrary)
        XCTAssertTrue(app.cells.staticTexts["Beck"].waitForExistence(timeout: 20),
                      "folder artists did not load")
    }

    func testMediaFolderDropdown() {
        let app = launch()
        openFolders(in: app)

        // The dropdown shows the selected folder and expands to the fixture folders
        let dropdown = app.buttons[AccessibilityId.libraryFolderDropdown]
        XCTAssertTrue(dropdown.waitForExistence(timeout: 10), "media folder dropdown missing")
        dropdown.tap()

        let musicItem = app.buttons["Music"].firstMatch
        XCTAssertTrue(musicItem.waitForExistence(timeout: 5), "dropdown did not expand")
        musicItem.tap()

        // Selecting a folder reloads the list for that folder (fixture returns the same
        // index either way, so just assert the list is intact and the selection stuck)
        XCTAssertTrue(app.cells.staticTexts["Beck"].waitForExistence(timeout: 20))
        XCTAssertEqual(dropdown.label, "Music")
    }

    func testFoldersDrillDownAndAlbumPlayAll() {
        let app = launch()
        openFolders(in: app)

        // Artist folder -> album folder -> disc folder with songs
        app.tapCell(containing: "Beck")
        XCTAssertTrue(app.cells.staticTexts["Odeley"].waitForExistence(timeout: 15), "artist folder did not load")

        // Play All at the artist level recursively queues the folder's songs
        let playAll = app.buttons["Play All"].firstMatch
        XCTAssertTrue(playAll.exists, "no Play All header at artist level")
        playAll.tap()
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 30),
                      "artist play-all did not open the player")

        // Drill to the album level and play all there too
        app.openTab(AccessibilityId.tabLibrary)
        app.tapCell(containing: "Odeley")
        XCTAssertTrue(app.cells.staticTexts["Disc 1"].waitForExistence(timeout: 15), "album folder did not load")
        let albumPlayAll = app.buttons["Play All"].firstMatch
        XCTAssertTrue(albumPlayAll.exists, "no Play All header at album level")
        albumPlayAll.tap()
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 30),
                      "album play-all did not open the player")
    }

    func testFoldersShuffle() {
        let app = launch()
        openFolders(in: app)

        app.tapCell(containing: "Beck")
        XCTAssertTrue(app.cells.staticTexts["Odeley"].waitForExistence(timeout: 15))

        let shuffle = app.buttons["Shuffle"].firstMatch
        XCTAssertTrue(shuffle.exists, "no Shuffle header at artist level")
        shuffle.tap()
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 30),
                      "artist shuffle did not open the player")
    }

    func testTagArtistsDrillDownAndSongPlayback() {
        let app = launch()
        app.openTab(AccessibilityId.tabLibrary)

        app.buttons["Artists"].firstMatch.tap()
        XCTAssertTrue(app.cells.staticTexts["Amanda Blank"].waitForExistence(timeout: 20),
                      "tag artists did not load")

        app.tapCell(containing: "Amanda Blank")
        XCTAssertTrue(app.cells.staticTexts["The Remixes"].waitForExistence(timeout: 15),
                      "tag artist albums did not load")

        app.tapCell(containing: "The Remixes")
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15), "tag album songs did not load")

        // Play the first song
        app.tapFirstCellText()
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 15),
                      "tapping a tag album song did not open the player")
    }

    func testSwipeToQueueAndCacheArtist() {
        let app = launch()
        openFolders(in: app)

        // Queue the whole artist folder from the swipe action
        app.swipeAction("Queue", onCellContaining: "Beck")

        // The queue fills asynchronously (recursive folder load), then check the play queue
        app.openTab(AccessibilityId.tabPlaylists)
        let countLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'song'")).firstMatch
        XCTAssertTrue(countLabel.waitForExistence(timeout: 30), "queued artist songs did not reach the play queue")

        // Download (cache) the artist from the swipe action
        app.openTab(AccessibilityId.tabLibrary)
        app.swipeAction("Download", onCellContaining: "Beck")
        app.triggerDownloadQueueStart()

        // Artist-level caching queues through the bulk addToDownloadQueue(serverId:songIds:),
        // which currently fails on malformed SQL (BUG-06…09); flips when the store fix lands
        XCTExpectFailure("BUG-06…09: bulk addToDownloadQueue is broken, artist swipe-to-cache downloads nothing", strict: false) {
            app.openTab(AccessibilityId.tabDownloads)
            app.buttons["Songs"].firstMatch.tap()
            XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 60),
                          "swipe-to-cache produced no downloaded songs")
        }
    }

    func testBookmarksOpenPlayAndDelete() {
        let app = launch()

        // Create a bookmark from the player
        app.startPlaybackViaServerShuffle()
        app.tapExpectingAlert(button: AccessibilityId.playerBookmarks, alertTitle: "Create Bookmark")
        app.fillAlert(titled: "Create Bookmark", text: "UITest Bookmark", confirm: "Save")

        // The bookmark shows up under Library > Bookmarks (the cell header carries its name)
        let bookmarkCell = app.cells.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "UITest Bookmark")).firstMatch
        app.openTab(AccessibilityId.tabLibrary)
        app.buttons["Bookmarks"].firstMatch.tap()
        XCTAssertTrue(bookmarkCell.waitForExistence(timeout: 15), "bookmark did not appear")

        // Opening the bookmark starts playback at the bookmark position
        bookmarkCell.tap()
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 15),
                      "opening a bookmark did not open the player")

        // Deleting via swipe removes the row (re-select the Bookmarks page explicitly —
        // a tab tap can get swallowed while the player HUD is still up)
        app.openTab(AccessibilityId.tabLibrary)
        let bookmarksPage = app.buttons["Bookmarks"].firstMatch
        if bookmarksPage.waitForExistence(timeout: 5) {
            bookmarksPage.tap()
        }
        XCTAssertTrue(bookmarkCell.waitForExistence(timeout: 15))
        XCTAssertTrue(waitUntil(timeout: 10) { bookmarkCell.isHittable })
        bookmarkCell.swipeLeft()
        let deleteButton = app.buttons["Delete"].firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "no Delete swipe action on bookmark")
        deleteButton.tap()
        // Deleted rows can linger in the accessibility tree, so assert on hittability
        XCTAssertTrue(waitUntil { !bookmarkCell.isHittable }, "bookmark was not deleted")
    }
}
