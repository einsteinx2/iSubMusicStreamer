//
//  OfflineUITests.swift
//  iSubUITests
//
//  Created by Benjamin Baron on 7/10/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// E2E-03 Offline mode: songs are seeded through the embedded mock HTTP server in an
// online launch, then the app is relaunched with -MODE offline (no mock server running,
// force-offline set before the UI loads) and verified per the OFFLINE MODE section of
// Testing/Integration Tests.txt adapted to the 5-tab layout: tab behavior, browsing and
// playing downloads at every level of the Downloads tab (which fills the offline
// browsing role of the old Artists/Genres tabs), offline play-queue editing and local
// playlists, offline bookmarks, the player, online<->offline reachability transitions
// (indicator banner + controls disabling), and settings/server-list reachability.
final class OfflineUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // Phase 1 (online, mock HTTP server): download the two fixture songs and wait for
    // them to be fully cached. Phase 2: relaunch offline without resetting state — the
    // mock server is gone and force-offline is set before the UI loads, so the app runs
    // purely from the downloaded content.
    private func launchOfflineWithDownloads() -> XCUIApplication {
        var app = ISubApp.launch(mockServer: true)
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

        app.terminate()
        app = ISubApp.launch(mode: "offline", resetState: false)
        app.waitForTabBar()
        return app
    }

    private func sliderValue(_ app: XCUIApplication) -> Double {
        let slider = app.sliders[AccessibilityId.playerSeekSlider]
        let value = slider.value as? String ?? "0%"
        return Double(value.replacingOccurrences(of: "%", with: "")) ?? 0
    }

    private var offlineIndicator: (XCUIApplication) -> XCUIElement {
        { $0.staticTexts["iSub is Offline"] }
    }

    // Returns to the Downloads tab root: a pushed drill-down screen hides the sub-tab
    // bar (it lives on the root screen's navigation item), so pop anything above it
    private func openDownloadsRoot(_ app: XCUIApplication) {
        app.openTab(AccessibilityId.tabDownloads)
        for _ in 0..<3 where !app.buttons["Songs"].firstMatch.exists {
            let back = app.navigationBars.buttons.firstMatch
            if back.exists {
                back.tap()
            }
        }
        XCTAssertTrue(app.buttons["Songs"].firstMatch.waitForExistence(timeout: 10),
                      "could not return to the Downloads root screen")
    }

    // Plays a downloaded song from Downloads > Songs and waits for the player
    private func playDownloadedSong(_ app: XCUIApplication, title: String,
                                    file: StaticString = #filePath, line: UInt = #line) {
        app.openTab(AccessibilityId.tabDownloads)
        app.buttons["Songs"].firstMatch.tap()
        app.tapCell(containing: title, file: file, line: line)
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 15),
                      "playing a downloaded song did not open the player", file: file, line: line)
    }

    func testOfflineTabBehaviorAndSettingsReachable() {
        let app = launchOfflineWithDownloads()

        // All five tabs stay in place offline
        for tab in [AccessibilityId.tabLibrary, AccessibilityId.tabPlaylists, AccessibilityId.tabPlayer,
                    AccessibilityId.tabDownloads, AccessibilityId.tabSettings] {
            XCTAssertTrue(app.tabBars.buttons[tab].exists, "tab \(tab) missing in offline mode")
        }

        // The offline indicator banner tells the user why everything is dimmed. The
        // launch offline check (BUG-24) posts didEnterOfflineMode even when the mode
        // was set before the UI loaded, so it shows on a cold offline launch too.
        XCTAssertTrue(waitUntil(timeout: 5) { self.offlineIndicator(app).isHittable },
                      "offline banner not visible after an offline launch")

        // The Browse page's server rows are disabled: tapping Shuffle All must do
        // nothing, and the server search bar disappears entirely
        app.openBrowsePage()
        XCTAssertFalse(app.searchFields.firstMatch.exists,
                       "the server search bar is visible while offline")
        app.cells[AccessibilityId.browseShuffleAll].firstMatch.tap()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
        XCTAssertEqual(app.sheets.count, 0, "server shuffle showed its folder picker while offline")
        XCTAssertFalse(app.buttons[AccessibilityId.playerPlayPause].isHittable,
                       "server shuffle started playback while offline")

        // Settings stay reachable, and the server list still shows the saved server
        app.openTab(AccessibilityId.tabSettings)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10),
                      "settings not reachable in offline mode")
        app.buttons[AccessibilityId.settingsSectionServers].tap()
        XCTAssertTrue(app.navigationBars["Servers"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10),
                      "server list is empty in offline mode")
    }

    func testBrowseAndPlayDownloadsAtEveryLevel() {
        let app = launchOfflineWithDownloads()
        app.openTab(AccessibilityId.tabDownloads)

        // Folders: the downloaded songs' path is "Formats/...", so the folder level
        // lists Formats and drilling in reaches the songs
        app.buttons["Folders"].firstMatch.tap()
        app.tapCell(containing: "Formats")
        XCTAssertTrue(app.cells.staticTexts["MP3 Song"].waitForExistence(timeout: 15),
                      "downloaded folder drill-down did not reach the songs")
        app.tapCell(containing: "MP3 Song")
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 15),
                      "playing from the downloaded folder level did not open the player")
        XCTAssertTrue(waitUntil(timeout: 20) { self.sliderValue(app) > 0 },
                      "offline playback from the folder level did not start")

        // Artists (tags): artist -> album -> song
        openDownloadsRoot(app)
        app.buttons["Artists"].firstMatch.tap()
        app.tapCell(containing: "Test Tones")
        app.tapCell(containing: "Formats")
        XCTAssertTrue(app.cells.staticTexts["FLAC Tone"].waitForExistence(timeout: 15),
                      "downloaded tag artist drill-down did not reach the songs")

        // Albums (tags): album -> song, playing the FLAC exercises BASS plugin loading offline
        openDownloadsRoot(app)
        app.buttons["Albums"].firstMatch.tap()
        app.tapCell(containing: "Formats")
        app.tapCell(containing: "FLAC Tone")
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 15),
                      "playing from the downloaded album level did not open the player")
        XCTAssertTrue(waitUntil(timeout: 20) { self.sliderValue(app) > 0 },
                      "offline FLAC playback did not start")

        // Songs: flat list plays directly, and swipe-to-queue appends to the play queue
        openDownloadsRoot(app)
        app.buttons["Songs"].firstMatch.tap()
        app.swipeAction("Queue", onCellContaining: "MP3 Song")
        app.openTab(AccessibilityId.tabPlaylists)
        let countLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'song'")).firstMatch
        XCTAssertTrue(countLabel.waitForExistence(timeout: 10), "queue view did not update after swipe-to-queue")
    }

    func testOfflinePlayQueueEditAndLocalPlaylists() {
        let app = launchOfflineWithDownloads()

        // Build a 2-song queue from the downloaded songs
        playDownloadedSong(app, title: "MP3 Song")
        app.openTab(AccessibilityId.tabPlaylists)
        XCTAssertTrue(app.buttons[AccessibilityId.saveEditHeaderEdit].waitForExistence(timeout: 15),
                      "play queue header did not appear")
        let table = app.tables.firstMatch
        XCTAssertTrue(waitUntil(timeout: 10) { table.cells.count == 2 }, "play queue does not have the 2 downloaded songs")

        // Reorder in edit mode
        let firstRowBefore = table.cells.element(boundBy: 0).staticTexts.allElementsBoundByIndex.map(\.label).joined()
        app.buttons[AccessibilityId.saveEditHeaderEdit].tap()
        let reorder = table.cells.element(boundBy: 0).buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder'")).firstMatch
        XCTAssertTrue(reorder.waitForExistence(timeout: 10), "no reorder control in offline edit mode")
        reorder.press(forDuration: 0.5, thenDragTo: table.cells.element(boundBy: 1))
        app.buttons[AccessibilityId.saveEditHeaderEdit].tap()
        let firstRowAfter = table.cells.element(boundBy: 0).staticTexts.allElementsBoundByIndex.map(\.label).joined()
        XCTAssertNotEqual(firstRowAfter, firstRowBefore, "reordering offline did not move the first song")

        // Save goes straight to the local save alert offline — no Local/Server location prompt
        app.buttons[AccessibilityId.saveEditHeaderSaveDelete].tap()
        XCTAssertFalse(app.alerts["Playlist Location"].waitForExistence(timeout: 2),
                       "offline save asked for a playlist location (server is unreachable)")
        app.fillAlert(titled: "Save Playlist", text: "Offline List", confirm: "Save")
        app.buttons["Local"].firstMatch.tap()
        XCTAssertTrue(app.cells.staticTexts["Offline List"].waitForExistence(timeout: 15),
                      "offline-saved local playlist not listed")

        // Saving the same name again must ask to overwrite instead of duplicating
        app.buttons["Play Queue"].firstMatch.tap()
        XCTAssertTrue(app.buttons[AccessibilityId.saveEditHeaderSaveDelete].waitForExistence(timeout: 10))
        app.buttons[AccessibilityId.saveEditHeaderSaveDelete].tap()
        app.fillAlert(titled: "Save Playlist", text: "Offline List", confirm: "Save")
        XCTExpectFailure("STUB: overwrite confirmation for duplicate local playlist names not implemented yet", strict: false) {
            let overwriteAlert = app.alerts.matching(NSPredicate(format: "label CONTAINS[c] 'overwrite'")).firstMatch
            XCTAssertTrue(overwriteAlert.waitForExistence(timeout: 5),
                          "no overwrite confirmation for an existing playlist name")
            if overwriteAlert.exists {
                overwriteAlert.buttons.element(boundBy: 1).tap()
            }
        }

        // Delete the currently playing song (row 0) in edit mode; playback must survive
        app.buttons[AccessibilityId.saveEditHeaderEdit].tap()
        table.cells.element(boundBy: 0).tap()
        app.buttons[AccessibilityId.saveEditHeaderSaveDelete].tap()
        XCTAssertTrue(waitUntil(timeout: 10) { table.cells.count == 1 },
                      "deleting the current song offline did not remove it")
        app.openTab(AccessibilityId.tabPlayer)
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 10),
                      "player broke after deleting the currently playing song offline")

        // The saved local playlist opens and lists its songs offline
        app.openTab(AccessibilityId.tabPlaylists)
        app.buttons["Local"].firstMatch.tap()
        app.tapCell(containing: "Offline List")
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15),
                      "local playlist songs did not load offline")
        app.tapFirstCellText()
        XCTExpectFailure("STUB: playing from a local playlist (LocalPlaylistViewController.didSelectRowAt) not implemented yet", strict: false) {
            XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 15),
                          "playing a local playlist song offline did not open the player")
        }
    }

    func testOfflinePlayerTransportAndBookmarks() {
        let app = launchOfflineWithDownloads()

        // The MP3 fixture is ~144s, long enough for the transport flows
        playDownloadedSong(app, title: "MP3 Song")
        XCTAssertTrue(waitUntil(timeout: 20) { self.sliderValue(app) > 0 }, "offline playback did not start")

        // Pause freezes progress, play resumes
        app.buttons[AccessibilityId.playerPlayPause].tap()
        let paused = sliderValue(app)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
        XCTAssertEqual(sliderValue(app), paused, accuracy: 1.5, "progress moved while paused offline")
        app.buttons[AccessibilityId.playerPlayPause].tap()
        XCTAssertTrue(waitUntil(timeout: 10) { self.sliderValue(app) > paused + 0.5 }, "offline playback did not resume")

        // ±30s quick skip works against the fully cached file
        let beforeSkip = sliderValue(app)
        app.buttons[AccessibilityId.playerQuickSkipForward].tap()
        XCTAssertTrue(waitUntil(timeout: 10) { self.sliderValue(app) > beforeSkip + 10 },
                      "offline quick skip forward did not jump ahead")
        app.buttons[AccessibilityId.playerQuickSkipBack].tap()
        XCTAssertTrue(waitUntil(timeout: 10) { self.sliderValue(app) < 15 },
                      "offline quick skip back did not jump back")

        // Seeking anywhere works offline since the whole file is cached
        app.sliders[AccessibilityId.playerSeekSlider].adjust(toNormalizedSliderPosition: 0.5)
        XCTAssertTrue(waitUntil(timeout: 10) { self.sliderValue(app) > 30 }, "offline seek did not jump")

        // Bookmarks are created and opened entirely locally
        app.buttons[AccessibilityId.playerBookmarks].tap()
        app.fillAlert(titled: "Create Bookmark", text: "Offline Bookmark", confirm: "Save")
        XCTAssertFalse(app.alerts["Error"].exists, "offline bookmark creation reported an error")

        app.openTab(AccessibilityId.tabLibrary)
        app.buttons["Bookmarks"].firstMatch.tap()
        // The bookmark row's header renders as "<name> - <offset>", so match by prefix
        let bookmarkText = app.cells.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Offline Bookmark")).firstMatch
        XCTAssertTrue(bookmarkText.waitForExistence(timeout: 15), "offline bookmark not listed")
        XCTAssertTrue(pollUntil(timeout: 10) { bookmarkText.isHittable }, "offline bookmark row not tappable")
        bookmarkText.tap()
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 15),
                      "opening an offline bookmark did not land on the player")
        XCTAssertTrue(waitUntil(timeout: 20) { self.sliderValue(app) > 0 },
                      "opening an offline bookmark did not resume playback")
    }

    func testOnlineOfflineTransitionBannerAndControls() {
        // Plain online launch against the URLProtocol stub; no downloads needed
        let app = ISubApp.launch()
        app.waitForTabBar()
        XCTAssertFalse(offlineIndicator(app).isHittable, "offline banner visible while online")

        // Settings > Network & Streaming > Force Offline Mode ON drives the goOffline transition
        app.openTab(AccessibilityId.tabSettings)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        app.buttons["settings.section.network"].tap()
        XCTAssertTrue(app.navigationBars["Network & Streaming"].waitForExistence(timeout: 10))
        app.tapToggle(AccessibilityId.optionsManualOfflineMode)

        // The "iSub is Offline" banner appears
        XCTAssertTrue(waitUntil(timeout: 10) { self.offlineIndicator(app).isHittable },
                      "offline banner did not appear after entering offline mode")

        // Back out of the section screen (which hides the tab bar) and the Browse
        // page's server rows are disabled
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.tabBars.buttons[AccessibilityId.tabLibrary].waitForExistence(timeout: 10))
        app.openBrowsePage()
        app.cells[AccessibilityId.browseShuffleAll].firstMatch.tap()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
        XCTAssertEqual(app.sheets.count, 0, "server shuffle responded while offline")
        XCTAssertFalse(app.buttons[AccessibilityId.playerPlayPause].isHittable,
                       "server shuffle started playback while offline")

        // Toggle force offline mode back OFF: goOnline fires, the banner hides and the
        // server controls come back to life
        app.openTab(AccessibilityId.tabSettings)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        app.buttons["settings.section.network"].tap()
        XCTAssertTrue(app.navigationBars["Network & Streaming"].waitForExistence(timeout: 10))
        app.tapToggle(AccessibilityId.optionsManualOfflineMode)
        XCTAssertTrue(waitUntil(timeout: 10) { !self.offlineIndicator(app).isHittable },
                      "offline banner did not hide after going back online")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.tabBars.buttons[AccessibilityId.tabLibrary].waitForExistence(timeout: 10))
        app.startPlaybackViaServerShuffle()
    }
}
