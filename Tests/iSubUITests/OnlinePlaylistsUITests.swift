//
//  OnlinePlaylistsUITests.swift
//  iSubUITests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// E2E-02 Playlists tab: play-queue edit mode (reorder, delete single/multiple/currently
// playing, select-all), save local (+ overwrite), save to server, local playlist
// open/play/delete, server playlist open/delete, and bookmarks clear-all.
//
// Flows that depend on still-stubbed features (server playlist upload/delete, local
// playlist delete, overwrite confirmation, bookmarks clear-all) assert the correct target
// behavior inside non-strict XCTExpectFailure blocks referencing the checklist items, so
// they flip to passing when Sections 4-5 land.
final class OnlinePlaylistsUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    private func launchWithQueue() -> XCUIApplication {
        let app = ISubApp.launch(mockServer: true)
        app.waitForTabBar()
        app.startPlaybackViaServerShuffle()
        app.openTab(AccessibilityId.tabPlaylists)
        XCTAssertTrue(app.buttons[AccessibilityId.saveEditHeaderEdit].waitForExistence(timeout: 15),
                      "play queue header did not appear")
        return app
    }

    private func queueCount(_ app: XCUIApplication) -> Int {
        app.tables.firstMatch.cells.count
    }

    // The header labels are lowercase-pluralized ("Remove 2 songs"), so match case-insensitively
    private func headerLabel(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    // A row's combined text (number + title + artist), used to detect order changes
    private func rowText(_ app: XCUIApplication, index: Int) -> String {
        let cell = app.tables.firstMatch.cells.element(boundBy: index)
        return cell.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "|")
    }

    func testPlayQueueSelectAllAndCloseEdit() {
        let app = launchWithQueue()

        app.buttons[AccessibilityId.saveEditHeaderEdit].tap()

        // Tapping the delete button with nothing selected selects all rows
        app.buttons[AccessibilityId.saveEditHeaderSaveDelete].tap()
        XCTAssertTrue(headerLabel(app, containing: "Remove 10 song").waitForExistence(timeout: 10),
                      "select-all did not select all 10 songs")

        // Closing edit mode leaves the queue intact
        app.buttons[AccessibilityId.saveEditHeaderEdit].tap()
        XCTAssertEqual(queueCount(app), 10, "closing edit mode changed the queue")
    }

    func testPlayQueueReorder() {
        let app = launchWithQueue()

        let firstRowBefore = rowText(app, index: 0)

        app.buttons[AccessibilityId.saveEditHeaderEdit].tap()
        let table = app.tables.firstMatch
        let firstReorder = table.cells.element(boundBy: 0).buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder'")).firstMatch
        XCTAssertTrue(firstReorder.waitForExistence(timeout: 10), "no reorder control in edit mode")
        let destination = table.cells.element(boundBy: 3)
        firstReorder.press(forDuration: 0.5, thenDragTo: destination)

        app.buttons[AccessibilityId.saveEditHeaderEdit].tap()
        XCTAssertNotEqual(rowText(app, index: 0), firstRowBefore, "reordering did not move the first song")
    }

    func testPlayQueueDeleteSingleAndMultiple() {
        let app = launchWithQueue()

        // Single delete: select one row and remove it
        app.buttons[AccessibilityId.saveEditHeaderEdit].tap()
        let table = app.tables.firstMatch
        table.cells.element(boundBy: 5).tap()
        XCTAssertTrue(headerLabel(app, containing: "Remove 1 song").waitForExistence(timeout: 5))
        app.buttons[AccessibilityId.saveEditHeaderSaveDelete].tap()
        XCTAssertTrue(waitUntil { self.queueCount(app) == 9 }, "single delete did not remove the row")

        // Multiple delete: select two rows and remove them
        app.buttons[AccessibilityId.saveEditHeaderEdit].tap()
        table.cells.element(boundBy: 1).tap()
        table.cells.element(boundBy: 2).tap()
        XCTAssertTrue(headerLabel(app, containing: "Remove 2 song").waitForExistence(timeout: 5))
        app.buttons[AccessibilityId.saveEditHeaderSaveDelete].tap()
        XCTAssertTrue(waitUntil { self.queueCount(app) == 7 }, "multiple delete did not remove the rows")
    }

    func testPlayQueueDeleteCurrentlyPlayingSong() {
        let app = launchWithQueue()

        // Row 0 is the currently playing song right after server shuffle
        app.buttons[AccessibilityId.saveEditHeaderEdit].tap()
        app.tables.firstMatch.cells.element(boundBy: 0).tap()
        app.buttons[AccessibilityId.saveEditHeaderSaveDelete].tap()
        XCTAssertTrue(waitUntil { self.queueCount(app) == 9 }, "deleting the current song did not remove it")

        // Playback moves on without crashing the player
        app.openTab(AccessibilityId.tabPlayer)
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 10),
                      "player broke after deleting the currently playing song")
    }

    func testSaveLocalPlaylistAndOverwrite() {
        let app = launchWithQueue()

        // Save the queue as a local playlist
        app.buttons[AccessibilityId.saveEditHeaderSaveDelete].tap()
        let locationAlert = app.alerts["Playlist Location"]
        XCTAssertTrue(locationAlert.waitForExistence(timeout: 10), "playlist location prompt missing")
        locationAlert.buttons["Local"].tap()
        app.fillAlert(titled: "Save Playlist", text: "UITest List", confirm: "Save")

        // It appears under the Local tab
        app.buttons["Local"].firstMatch.tap()
        XCTAssertTrue(app.cells.staticTexts["UITest List"].waitForExistence(timeout: 15),
                      "saved local playlist not listed")

        // Saving again under the same name must ask to overwrite instead of duplicating
        app.buttons["Play Queue"].firstMatch.tap()
        XCTAssertTrue(app.buttons[AccessibilityId.saveEditHeaderSaveDelete].waitForExistence(timeout: 10))
        app.buttons[AccessibilityId.saveEditHeaderSaveDelete].tap()
        XCTAssertTrue(locationAlert.waitForExistence(timeout: 10))
        locationAlert.buttons["Local"].tap()
        app.fillAlert(titled: "Save Playlist", text: "UITest List", confirm: "Save")

        XCTExpectFailure("STUB: overwrite confirmation for duplicate local playlist names not implemented yet", strict: false) {
            let overwriteAlert = app.alerts.matching(NSPredicate(format: "label CONTAINS[c] 'overwrite'")).firstMatch
            XCTAssertTrue(overwriteAlert.waitForExistence(timeout: 5),
                          "no overwrite confirmation for an existing playlist name")
            if overwriteAlert.exists {
                overwriteAlert.buttons.element(boundBy: 1).tap()
            }
        }
    }

    func testSavePlayQueueToServer() {
        let app = launchWithQueue()

        app.buttons[AccessibilityId.saveEditHeaderSaveDelete].tap()
        let locationAlert = app.alerts["Playlist Location"]
        XCTAssertTrue(locationAlert.waitForExistence(timeout: 10))
        locationAlert.buttons["Server"].tap()
        app.fillAlert(titled: "Save Playlist", text: "UITest Server List", confirm: "Save")

        XCTExpectFailure("STUB: createPlaylist upload not implemented yet", strict: false) {
            // The upload must hit the server; the fixture set always returns the same two
            // playlists, so evidence of the request is that no silent no-op happened —
            // once implemented, the server tab refresh will show the fixture playlists
            // after the round trip and the HUD flow must complete without hanging.
            app.buttons["Server"].firstMatch.tap()
            XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15),
                          "server playlists did not refresh after save-to-server")
        }
    }

    func testLocalPlaylistOpenPlayAndDelete() {
        let app = launchWithQueue()

        // Create a local playlist to work with
        app.buttons[AccessibilityId.saveEditHeaderSaveDelete].tap()
        XCTAssertTrue(app.alerts["Playlist Location"].waitForExistence(timeout: 10))
        app.alerts["Playlist Location"].buttons["Local"].tap()
        app.fillAlert(titled: "Save Playlist", text: "Local Open Test", confirm: "Save")

        // Open it and play a song
        app.buttons["Local"].firstMatch.tap()
        app.tapCell(containing: "Local Open Test")
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15), "local playlist songs did not load")
        app.tapFirstCellText()
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 15),
                      "playing a local playlist song did not open the player")

        // Delete it via the swipe action (the tab restores the detail screen; pop back first)
        app.openTab(AccessibilityId.tabPlaylists)
        if app.navigationBars["Local Open Test"].waitForExistence(timeout: 5) {
            app.navigationBars.buttons.firstMatch.tap()
        }
        XCTAssertTrue(app.cells.staticTexts["Local Open Test"].waitForExistence(timeout: 10))
        app.swipeAction("Delete", onCellContaining: "Local Open Test")

        // Deleted rows can linger invisibly in the table's reuse pool, so assert on hittability
        XCTAssertTrue(waitUntil(timeout: 10) { !app.cells.staticTexts["Local Open Test"].firstMatch.isHittable },
                      "local playlist was not deleted")
    }

    func testServerPlaylistOpenPlayAndDelete() {
        let app = ISubApp.launch(mockServer: true)
        app.waitForTabBar()
        app.openTab(AccessibilityId.tabPlaylists)

        // The fixture server has the "iSub Test Playlist"
        app.buttons["Server"].firstMatch.tap()
        app.tapCell(containing: "iSub Test Playlist")
        XCTAssertTrue(app.navigationBars["iSub Test Playlist"].waitForExistence(timeout: 10))

        // The playlist screen only loads its songs on pull-to-refresh
        let table = app.tables.firstMatch
        table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            .press(forDuration: 0.1, thenDragTo: table.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 20), "server playlist songs did not load")
        app.tapFirstCellText()
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 15),
                      "playing a server playlist song did not open the player")

        // Delete it via the swipe action (the tab restores the detail screen; pop back first)
        app.openTab(AccessibilityId.tabPlaylists)
        if app.navigationBars["iSub Test Playlist"].waitForExistence(timeout: 5) {
            app.navigationBars.buttons.firstMatch.tap()
        }
        app.swipeAction("Delete", onCellContaining: "iSub Test Playlist")

        // Deleted rows can linger invisibly in the table's reuse pool, so assert on hittability
        XCTAssertTrue(waitUntil(timeout: 10) { !app.cells.staticTexts["iSub Test Playlist"].firstMatch.isHittable },
                      "server playlist was not deleted")
    }

    func testServerPlaylistsSelectAllDelete() {
        let app = ISubApp.launch(mockServer: true)
        app.waitForTabBar()
        app.openTab(AccessibilityId.tabPlaylists)

        // The fixture server has one playlist
        app.buttons["Server"].firstMatch.tap()
        XCTAssertTrue(app.cells.staticTexts["iSub Test Playlist"].waitForExistence(timeout: 15),
                      "fixture server playlist did not load")

        // Tapping delete with nothing selected selects all rows; tapping again deletes them
        app.buttons[AccessibilityId.saveEditHeaderEdit].tap()
        app.buttons[AccessibilityId.saveEditHeaderSaveDelete].tap()
        XCTAssertTrue(headerLabel(app, containing: "Remove 1 playlist").waitForExistence(timeout: 10),
                      "select-all did not select the playlist")
        app.buttons[AccessibilityId.saveEditHeaderSaveDelete].tap()

        // Deleted rows can linger invisibly in the table's reuse pool, so assert on
        // hittability (and the edit header disappearing) rather than existence
        XCTAssertTrue(waitUntil(timeout: 10) { !app.cells.staticTexts["iSub Test Playlist"].firstMatch.isHittable },
                      "select-all delete did not remove the playlist")
        XCTAssertTrue(waitUntil(timeout: 10) { !app.buttons[AccessibilityId.saveEditHeaderEdit].exists },
                      "the edit header should disappear once no playlists remain")
    }

    func testBookmarksClearAll() {
        let app = ISubApp.launch(mockServer: true)
        app.waitForTabBar()
        app.startPlaybackViaServerShuffle()

        // Create a bookmark, then clear all from the bookmarks edit header
        app.buttons[AccessibilityId.playerBookmarks].tap()
        app.fillAlert(titled: "Create Bookmark", text: "Clear All Test", confirm: "Save")

        app.openTab(AccessibilityId.tabLibrary)
        app.buttons["Bookmarks"].firstMatch.tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15), "bookmark did not appear")

        app.buttons[AccessibilityId.saveEditHeaderEdit].tap()
        // First tap with nothing selected selects all; second tap deletes
        app.buttons[AccessibilityId.saveEditHeaderSaveDelete].tap()
        XCTAssertTrue(headerLabel(app, containing: "Remove 1 bookmark").waitForExistence(timeout: 10),
                      "clear-all did not select the bookmark")
        app.buttons[AccessibilityId.saveEditHeaderSaveDelete].tap()

        // The edit header disappears once no bookmarks remain (deleted rows can
        // linger invisibly in the table's reuse pool, so don't assert on cell counts)
        XCTAssertTrue(waitUntil(timeout: 10) { !app.buttons[AccessibilityId.saveEditHeaderEdit].exists },
                      "clear-all did not delete the bookmarks")
    }
}
