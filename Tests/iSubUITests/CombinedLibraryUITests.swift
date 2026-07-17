//
//  CombinedLibraryUITests.swift
//  iSubUITests
//
//  Created by Ben Baron on 7/17/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// E2E for the Combined Library: two seeded servers (-SERVERS 2; server two answers
// with the *_server2.xml fixtures and carries the "Server Two" nickname), covering
// the servers-screen entry flow with its one-time notices, merged browsing with
// badges, per-context queue/playlist isolation, merged search, and the
// delete-down-to-one forced switch.
final class CombinedLibraryUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    private func launchTwoServers() -> XCUIApplication {
        let app = ISubApp.launch(extraArguments: ["-SERVERS", "2"])
        app.waitForTabBar()
        return app
    }

    private func openServers(in app: XCUIApplication) {
        app.openTab(AccessibilityId.tabSettings)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        app.buttons[AccessibilityId.settingsSectionServers].tap()
        XCTAssertTrue(app.navigationBars["Servers"].waitForExistence(timeout: 10))
    }

    // Enters Combined from the servers screen, handling the one-time explainer
    private func enterCombined(in app: XCUIApplication, expectIntro: Bool) {
        openServers(in: app)
        let combinedRow = app.staticTexts["Combined Library"].firstMatch
        XCTAssertTrue(combinedRow.waitForExistence(timeout: 10), "no Combined Library row with two servers")
        combinedRow.tap()

        let intro = app.alerts["Combined Library"]
        if expectIntro {
            XCTAssertTrue(intro.waitForExistence(timeout: 5), "the first entry must show the explainer")
            intro.buttons["Enable"].tap()
        } else {
            XCTAssertFalse(intro.waitForExistence(timeout: 2), "the explainer must only show once")
        }
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10),
                      "entering Combined must pop back to the settings root")
    }

    private func openLibraryFolders(in app: XCUIApplication) {
        app.openTab(AccessibilityId.tabLibrary)
        let foldersTab = app.buttons["Folders"].firstMatch
        if foldersTab.waitForExistence(timeout: 5) {
            foldersTab.tap()
        }
    }

    private func openPlayQueue(in app: XCUIApplication) {
        app.openTab(AccessibilityId.tabPlaylists)
        let playQueueTab = app.buttons["Play Queue"].firstMatch
        if playQueueTab.waitForExistence(timeout: 5) {
            playQueueTab.tap()
        }
    }

    // Hidden tabs keep their stale view hierarchies in the element tree, so `exists`
    // alone can match an offscreen leftover copy of a row. Visibility (hittability)
    // is what these flows actually assert.
    private func assertCellVisible(_ app: XCUIApplication, _ text: String, timeout: TimeInterval = 15,
                                   _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = app.cells.staticTexts[text].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message, file: file, line: line)
        XCTAssertTrue(pollUntil(timeout: 10) { element.isHittable }, message, file: file, line: line)
    }

    private func assertCellNotVisible(_ app: XCUIApplication, _ text: String, settle: TimeInterval = 3,
                                      _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = app.cells.staticTexts[text].firstMatch
        _ = element.waitForExistence(timeout: settle)
        XCTAssertFalse(element.isHittable, message, file: file, line: line)
    }

    // The merged list is alphabetical across servers, so a target row (e.g. the
    // Z-section fixture artist) can sit far below the fold — scroll it into reach
    private func tapCellScrollingIfNeeded(_ app: XCUIApplication, _ text: String, timeout: TimeInterval = 45,
                                          file: StaticString = #filePath, line: UInt = #line) {
        let element = app.cells.staticTexts[text].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "no cell containing '\(text)'", file: file, line: line)
        var swipes = 0
        while !element.isHittable && swipes < 10 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.isHittable, "cell containing '\(text)' never scrolled into reach", file: file, line: line)
        element.tap()
    }

    func testCombinedRowHiddenWithSingleServer() {
        let app = ISubApp.launch()
        app.waitForTabBar()
        openServers(in: app)

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10), "servers list is empty")
        XCTAssertFalse(app.staticTexts["Combined Library"].exists, "one server has nothing to combine")
    }

    func testEnterCombinedMergesLibrariesWithBadges() {
        let app = launchTwoServers()
        enterCombined(in: app, expectIntro: true)

        // The merged Folders list fans out to both servers on first appearance
        openLibraryFolders(in: app)
        XCTAssertTrue(app.cells.staticTexts["Beck"].waitForExistence(timeout: 45),
                      "server one's artists missing from the merged list")
        XCTAssertTrue(app.cells.staticTexts["Zebra Ensemble"].waitForExistence(timeout: 45),
                      "server two's artists missing from the merged list")

        // Badges: server two shows its nickname, server one falls back to its host
        XCTAssertTrue(app.cells.staticTexts["Server Two"].firstMatch.exists, "nickname badge missing")
        XCTAssertTrue(app.cells.staticTexts["uitest.local"].firstMatch.exists, "host-fallback badge missing")

        // The per-server media-folder dropdown has no place in the merged view
        XCTAssertFalse(app.staticTexts["All Media Folders"].exists, "media-folder dropdown must hide in Combined")

        // The Server playlists tab merges every server's playlists
        app.openTab(AccessibilityId.tabPlaylists)
        let serverTab = app.buttons["Server"].firstMatch
        XCTAssertTrue(serverTab.waitForExistence(timeout: 10), "no Server playlists page")
        serverTab.tap()
        XCTAssertTrue(app.cells.staticTexts["iSub Test Playlist"].waitForExistence(timeout: 30),
                      "server one's playlist missing")
        XCTAssertTrue(app.cells.staticTexts["Server Two Playlist"].waitForExistence(timeout: 30),
                      "server two's playlist missing")
    }

    func testQueueAndLocalPlaylistsStayPerContext() {
        let app = launchTwoServers()

        // Queue a server-one song in single-server mode
        app.drillToFixtureSongs()
        app.swipeAction("Queue", onCellContaining: "MP3 Song")
        openPlayQueue(in: app)
        assertCellVisible(app, "MP3 Song", "queued song missing from server one's play queue")

        // Combined starts with its own clean queue
        enterCombined(in: app, expectIntro: true)
        openPlayQueue(in: app)
        assertCellNotVisible(app, "MP3 Song", "Combined must start with its own empty queue")

        // Queue server two's song from the merged library
        openLibraryFolders(in: app)
        tapCellScrollingIfNeeded(app, "Zebra Ensemble")
        app.swipeAction("Queue", onCellContaining: "Zebra Song")

        // Saving the Combined queue skips the Local/Server location choice entirely
        openPlayQueue(in: app)
        assertCellVisible(app, "Zebra Song", "server two's song missing from the Combined queue")
        app.buttons[AccessibilityId.saveEditHeaderSaveDelete].tap()
        XCTAssertFalse(app.alerts["Playlist Location"].waitForExistence(timeout: 2),
                       "Combined has no single server to upload to — no location choice")
        app.fillAlert(titled: "Save Playlist", text: "Combined Mix", confirm: "Save")
        app.buttons["Local"].firstMatch.tap()
        assertCellVisible(app, "Combined Mix", "the Combined-context playlist was not saved")

        // Switching to server one shows the one-time exit note, then restores its state
        openServers(in: app)
        app.tapCell(containing: "uitest.local")
        let exitNote = app.alerts["Switching to a Single Server"]
        XCTAssertTrue(exitNote.waitForExistence(timeout: 5), "leaving Combined must show the one-time note")
        exitNote.buttons["Switch"].tap()
        XCTAssertTrue(app.tabBars.buttons[AccessibilityId.tabLibrary].waitForExistence(timeout: 20))

        openPlayQueue(in: app)
        assertCellVisible(app, "MP3 Song", "server one's queue must come back exactly as left")
        assertCellNotVisible(app, "Zebra Song", "the Combined queue must not leak into server one")
        app.buttons["Local"].firstMatch.tap()
        assertCellNotVisible(app, "Combined Mix", "Combined-context playlists must not appear on a single server")

        // Re-entering Combined is instant (no intro) and everything is back
        enterCombined(in: app, expectIntro: false)
        openPlayQueue(in: app)
        assertCellVisible(app, "Zebra Song", "the Combined queue must come back on re-entry")
        app.buttons["Local"].firstMatch.tap()
        assertCellVisible(app, "Combined Mix", "the Combined playlist must come back on re-entry")
    }

    func testCombinedSearchMergesServers() {
        let app = launchTwoServers()
        enterCombined(in: app, expectIntro: true)

        app.openBrowsePage()
        app.tapCell(containing: "Server Search")
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 10), "no search field")
        searchField.tap()
        searchField.typeText("beck\n")

        // Both servers answer (the stub ignores the query); the merged Artists page
        // shows results from each
        XCTAssertTrue(app.cells.staticTexts["Beck"].waitForExistence(timeout: 30),
                      "server one's search results missing")
        XCTAssertTrue(app.cells.staticTexts["Zebra Ensemble"].waitForExistence(timeout: 30),
                      "server two's search results missing")
    }

    func testDeletingDownToOneServerForcesSwitch() {
        let app = launchTwoServers()
        enterCombined(in: app, expectIntro: true)

        openServers(in: app)
        let secondRow = app.cells.staticTexts["Server Two"].firstMatch
        XCTAssertTrue(secondRow.waitForExistence(timeout: 10))
        secondRow.swipeLeft()
        let deleteButton = app.buttons["Delete"].firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "no Delete swipe action")
        deleteButton.tap()

        // One server can't combine: iSub switches to it with a notice
        let notice = app.alerts["Notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 10), "the forced switch must be announced")
        XCTAssertTrue(notice.staticTexts.element(boundBy: 1).label.contains("at least two servers"),
                      "unexpected notice text")
        notice.buttons["OK"].tap()

        // The forced switch keeps the servers screen in place (popping it out from
        // under the notice wedges navigation), and its list refreshes on the switch
        XCTAssertTrue(waitUntil(timeout: 10) { !app.staticTexts["Combined Library"].exists },
                      "the Combined row must disappear with one server left")
        XCTAssertEqual(app.cells.count, 1)
    }
}
