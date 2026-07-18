//
//  CarPlayUITests.swift
//  iSubUITests
//
//  Created by Ben Baron on 7/18/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// E2E coverage for the CarPlay layer, driven through the -CARPLAY mirror (see
// CarPlayUITestMirror.swift): the real CarPlayManager builds real CPListTemplates
// in the app process, the mirror renders them natively, and row taps invoke the
// real CPListItem handlers — exercising template content, navigation, playback
// wiring, offline behavior, and the jukebox handoff end-to-end. The car's actual
// rendered screen has no public automation hooks, so this is the testable
// boundary; template-building logic is additionally unit tested in iSubTests.
final class CarPlayUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    // MARK: Helpers

    private func launchCarPlay(mode: String? = nil, mockServer: Bool = true,
                               extraArguments: [String] = []) -> XCUIApplication {
        let app = ISubApp.launch(mode: mode, mockServer: mockServer,
                                 extraArguments: ["-CARPLAY"] + extraArguments)
        XCTAssertTrue(app.buttons[AccessibilityId.carPlayPhone].waitForExistence(timeout: 30),
                      "CarPlay mirror did not appear")
        return app
    }

    private func carList(_ app: XCUIApplication) -> XCUIElement {
        app.tables[AccessibilityId.carPlayList]
    }

    private func carCell(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        // CONTAINS, not exact: song rows carry track-number prefixes ("1. MP3 Song")
        carList(app).cells.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    @discardableResult
    private func tapCarCell(_ app: XCUIApplication, containing text: String, timeout: TimeInterval = 20,
                            file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let element = carCell(app, containing: text)
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "no CarPlay row containing '\(text)'", file: file, line: line)
        XCTAssertTrue(pollUntil(timeout: 10) { element.isHittable }, "CarPlay row '\(text)' is not tappable", file: file, line: line)
        element.tap()
        // Every car row tap navigates or starts playback, so the row should leave
        // the foreground; if it's still hittable the tap was eaten by a cell swap
        // mid-reload — tap once more. (Flows where the tapped text recurs on the
        // next screen must use tapCarCellOnce instead.)
        if !pollUntil(timeout: 2, { !element.isHittable }), element.isHittable {
            element.tap()
        }
        return true
    }

    // No-retry variant for rows whose text also appears on the destination screen
    // (retrying there would tap the wrong element)
    private func tapCarCellOnce(_ app: XCUIApplication, containing text: String, timeout: TimeInterval = 20,
                                file: StaticString = #filePath, line: UInt = #line) {
        let element = carCell(app, containing: text)
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "no CarPlay row containing '\(text)'", file: file, line: line)
        XCTAssertTrue(pollUntil(timeout: 10) { element.isHittable }, "CarPlay row '\(text)' is not tappable", file: file, line: line)
        element.tap()
    }

    private func openCarTab(_ app: XCUIApplication, _ title: String,
                            file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[AccessibilityId.carPlayTab(title)].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15), "no CarPlay tab '\(title)'", file: file, line: line)
        button.tap()
    }

    // Waits for the mirror's Now Playing panel and returns the displayed song title
    @discardableResult
    private func waitForCarNowPlaying(_ app: XCUIApplication, timeout: TimeInterval = 30,
                                      file: StaticString = #filePath, line: UInt = #line) -> String {
        let title = app.staticTexts[AccessibilityId.carPlayNowPlayingTitle].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: timeout), "CarPlay Now Playing did not appear", file: file, line: line)
        XCTAssertTrue(pollUntil(timeout: 15) { title.label != "Nothing Playing" && !title.label.isEmpty },
                      "CarPlay Now Playing has no current song", file: file, line: line)
        return title.label
    }

    private func carTabButton(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        app.buttons[AccessibilityId.carPlayTab(title)].firstMatch
    }

    // MARK: Tabs and Library

    func testTabsShowOnlineOrderAndLibraryRows() {
        let app = launchCarPlay()

        // Online tab order: Library, Playlists, Downloads, Discover (left to right)
        for title in ["Library", "Playlists", "Downloads", "Discover"] {
            XCTAssertTrue(carTabButton(app, title).waitForExistence(timeout: 15), "missing CarPlay tab '\(title)'")
        }
        let libraryX = carTabButton(app, "Library").frame.minX
        let playlistsX = carTabButton(app, "Playlists").frame.minX
        let downloadsX = carTabButton(app, "Downloads").frame.minX
        let discoverX = carTabButton(app, "Discover").frame.minX
        XCTAssertLessThan(libraryX, playlistsX)
        XCTAssertLessThan(playlistsX, downloadsX)
        XCTAssertLessThan(downloadsX, discoverX)

        // Library root mirrors the phone's Library sub-tabs (minus Browse, which
        // lives in Discover)
        for row in ["Folders", "Artists", "Bookmarks"] {
            XCTAssertTrue(carCell(app, containing: row).waitForExistence(timeout: 15), "missing Library row '\(row)'")
        }
    }

    func testFoldersDrillDownToSongPlaybackAndQueue() {
        let app = launchCarPlay()

        // Library > Folders: the media-folder picker row appears (fixtures have two
        // real folders) along with the A-Z artist list
        tapCarCell(app, containing: "Folders")
        XCTAssertTrue(carCell(app, containing: "Media Folder").waitForExistence(timeout: 20),
                      "media folder picker row missing with multiple folders")
        tapCarCell(app, containing: "Beck")
        tapCarCell(app, containing: "Odeley")

        // Folder contents show play/shuffle actions and the album subfolders
        XCTAssertTrue(carCell(app, containing: "Play All").waitForExistence(timeout: 20))
        XCTAssertTrue(carCell(app, containing: "Shuffle").exists)
        tapCarCell(app, containing: "Disc 1")

        // Tapping a song plays it and lands on the car's Now Playing screen
        tapCarCell(app, containing: "MP3 Song")
        let firstTitle = waitForCarNowPlaying(app)
        XCTAssertTrue(firstTitle.contains("MP3 Song"), "unexpected now playing title '\(firstTitle)'")

        // Up Next shows the queue with the current song flagged; tapping another row
        // jumps to it and pops back down to Now Playing
        app.buttons[AccessibilityId.carPlayNowPlayingUpNext].tap()
        let playingRow = carList(app).cells.matching(NSPredicate(format: "value == 'playing'")).firstMatch
        XCTAssertTrue(playingRow.waitForExistence(timeout: 15), "queue does not flag the playing row")
        tapCarCell(app, containing: "FLAC Tone")
        let secondTitle = waitForCarNowPlaying(app)
        XCTAssertTrue(secondTitle.contains("Tone"), "queue jump did not change the song ('\(secondTitle)')")

        // The phone's player shows the same song the car started
        app.buttons[AccessibilityId.carPlayPhone].tap()
        app.openTab(AccessibilityId.tabPlayer)
        let phoneTitle = app.staticTexts[AccessibilityId.playerSongTitle].firstMatch
        XCTAssertTrue(phoneTitle.waitForExistence(timeout: 15), "phone player title missing")
        XCTAssertTrue(pollUntil(timeout: 10) { phoneTitle.label.contains("Tone") },
                      "phone player shows a different song than the car")

        // And the mirror reopens from the floating button
        app.buttons[AccessibilityId.carPlayToggle].tap()
        XCTAssertTrue(app.buttons[AccessibilityId.carPlayPhone].waitForExistence(timeout: 10),
                      "CarPlay mirror did not reopen")
    }

    func testMediaFolderPickerSelection() {
        let app = launchCarPlay()

        tapCarCell(app, containing: "Folders")
        // No-retry taps: "Media Folder" recurs as the picker's "All Media Folders"
        // row, and "Podcasts" recurs as the picker row's subtitle after selection
        tapCarCellOnce(app, containing: "Media Folder")

        // Picker lists the synthetic all-folders entry plus the fixture folders
        for row in ["All Media Folders", "Music", "Podcasts"] {
            XCTAssertTrue(carCell(app, containing: row).waitForExistence(timeout: 15), "missing media folder '\(row)'")
        }
        tapCarCellOnce(app, containing: "Podcasts")

        // Selection pops back to the artist list and the picker row shows the choice
        // (the fixture stub serves the same index for every folder, so the list
        // itself doesn't change — the persisted selection is what's asserted)
        XCTAssertTrue(carCell(app, containing: "Podcasts").waitForExistence(timeout: 15),
                      "picker row does not reflect the selected media folder")
        XCTAssertTrue(carCell(app, containing: "Beck").exists, "artist list disappeared after folder selection")
    }

    func testTagArtistsAlbumPlayAll() {
        let app = launchCarPlay()

        tapCarCell(app, containing: "Artists")
        tapCarCell(app, containing: "Amanda Blank")
        tapCarCell(app, containing: "The Remixes")

        // The album screen offers play/shuffle plus the songs
        XCTAssertTrue(carCell(app, containing: "Might Like You Better").waitForExistence(timeout: 20),
                      "album songs did not load")
        tapCarCell(app, containing: "Play All")
        let title = waitForCarNowPlaying(app)
        XCTAssertTrue(title.contains("Might Like You Better"), "play all did not start the album ('\(title)')")

        // The queue lists the album (one fixture song) with the current row flagged
        app.buttons[AccessibilityId.carPlayNowPlayingUpNext].tap()
        let playingRow = carList(app).cells.matching(NSPredicate(format: "value == 'playing'")).firstMatch
        XCTAssertTrue(playingRow.waitForExistence(timeout: 15), "queue does not flag the playing row")
    }

    // MARK: Playlists

    func testServerPlaylistPlaybackAndPlayQueueScreen() {
        let app = launchCarPlay()

        openCarTab(app, "Playlists")
        for row in ["Play Queue", "Local Playlists", "Server Playlists"] {
            XCTAssertTrue(carCell(app, containing: row).waitForExistence(timeout: 15), "missing Playlists row '\(row)'")
        }

        tapCarCell(app, containing: "Server Playlists")
        tapCarCell(app, containing: "iSub Test Playlist")
        tapCarCell(app, containing: "Going Crazy")
        let title = waitForCarNowPlaying(app)
        XCTAssertTrue(title.contains("Going Crazy"), "unexpected now playing title '\(title)'")

        // The Playlists tab's Play Queue screen shows the same queue (tab switch
        // collapses the pushed stack, like the real car UI)
        openCarTab(app, "Playlists")
        tapCarCell(app, containing: "Play Queue")
        let playingRow = carList(app).cells.matching(NSPredicate(format: "value == 'playing'")).firstMatch
        XCTAssertTrue(playingRow.waitForExistence(timeout: 15), "play queue does not flag the current song")
        XCTAssertTrue(carList(app).cells.count > 1, "server playlist queued fewer than 2 songs")
    }

    // MARK: Discover

    func testDiscoverQuickAlbumsLoadMoreAndShuffleAll() {
        let app = launchCarPlay()

        openCarTab(app, "Discover")
        for row in ["Recently Added", "Recently Played", "Frequently Played", "Random Albums", "Shuffle All"] {
            XCTAssertTrue(carCell(app, containing: row).waitForExistence(timeout: 15), "missing Discover row '\(row)'")
        }

        // Quick albums live-load a 20-item page, so the pager row appears
        tapCarCell(app, containing: "Recently Added")
        XCTAssertTrue(carCell(app, containing: "Fear EP").waitForExistence(timeout: 20), "quick albums did not load")
        XCTAssertTrue(carList(app).staticTexts["Load More…"].waitForExistence(timeout: 10),
                      "full page did not offer Load More")

        // Albums drill into browsable folder contents
        tapCarCell(app, containing: "Fear EP")
        XCTAssertTrue(carCell(app, containing: "Play All").waitForExistence(timeout: 20),
                      "quick album did not open folder contents")

        // Shuffle All offers the folder scope (two fixture folders) and starts playback
        openCarTab(app, "Discover")
        tapCarCell(app, containing: "Shuffle All")
        tapCarCell(app, containing: "All Media Folders")
        waitForCarNowPlaying(app)
    }

    // MARK: Offline

    func testOfflineTabOrderAndEmptyStates() {
        let app = launchCarPlay(mode: "offline", mockServer: false)

        // Offline reorders Downloads-first, and with nothing downloaded the initial
        // screen is the Downloads empty state
        let empty = app.staticTexts[AccessibilityId.carPlayEmptyTitle].firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 20), "no empty state shown offline")
        XCTAssertTrue(pollUntil(timeout: 10) { empty.label == "No Downloaded Songs" },
                      "offline launch did not land on the Downloads tab ('\(empty.label)')")

        let downloadsX = carTabButton(app, "Downloads").frame.minX
        let playlistsX = carTabButton(app, "Playlists").frame.minX
        let libraryX = carTabButton(app, "Library").frame.minX
        let discoverX = carTabButton(app, "Discover").frame.minX
        XCTAssertLessThan(downloadsX, playlistsX, "Downloads is not the first tab offline")
        XCTAssertLessThan(playlistsX, libraryX)
        XCTAssertLessThan(libraryX, discoverX)

        // The server-dependent Discover tab explains itself instead of listing rows
        openCarTab(app, "Discover")
        XCTAssertTrue(pollUntil(timeout: 10) { empty.label == "Offline Mode" },
                      "Discover does not show the offline empty state ('\(empty.label)')")

        // Library still offers its rows (cached browsing stays reachable)
        openCarTab(app, "Library")
        XCTAssertTrue(carCell(app, containing: "Bookmarks").waitForExistence(timeout: 15))
    }

    // MARK: Jukebox

    func testJukeboxAutoDisabledAndStreamsLocally() {
        let requestLogPath = NSTemporaryDirectory() + "carplay-requests-\(UUID().uuidString).log"
        defer { try? FileManager.default.removeItem(atPath: requestLogPath) }

        // Jukebox mode is on at launch; the CarPlay connect must flip it off so the
        // car plays locally instead of driving the home server's speakers
        let app = launchCarPlay(mode: "jukebox", mockServer: false,
                                extraArguments: ["-REQUESTLOG", requestLogPath])

        tapCarCell(app, containing: "Folders")
        tapCarCell(app, containing: "Beck")
        tapCarCell(app, containing: "Odeley")
        tapCarCell(app, containing: "Disc 1")
        tapCarCell(app, containing: "MP3 Song")
        waitForCarNowPlaying(app)

        // Local streaming happened; no remote jukebox playback commands were issued
        // after the connect (a stop from the disable handoff is allowed)
        XCTAssertTrue(pollUntil(timeout: 15) {
            (try? String(contentsOfFile: requestLogPath, encoding: .utf8))?.contains("stream?") == true
        }, "car playback did not stream locally")
        let log = (try? String(contentsOfFile: requestLogPath, encoding: .utf8)) ?? ""
        for banned in ["action=add", "action=skip", "action=start"] {
            XCTAssertFalse(log.contains(banned), "jukebox command issued after CarPlay disable: \(banned)")
        }

        // The phone player reflects local mode (no jukebox volume control)
        app.buttons[AccessibilityId.carPlayPhone].tap()
        app.openTab(AccessibilityId.tabPlayer)
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 15))
        XCTAssertFalse(app.sliders[AccessibilityId.playerJukeboxVolume].exists,
                       "jukebox mode still active after CarPlay connect")
    }

    // MARK: Bookmarks

    func testBookmarkPlaybackFromCar() {
        let app = launchCarPlay()

        // Create a bookmark through the phone UI (bookmark creation is phone-only
        // by design), then play it from the car
        app.buttons[AccessibilityId.carPlayPhone].tap()
        app.waitForTabBar()
        app.startPlaybackViaServerShuffle()
        app.tapExpectingAlert(button: AccessibilityId.playerBookmarks, alertTitle: "Create Bookmark")
        app.fillAlert(titled: "Create Bookmark", text: "Car Bookmark", confirm: "Save")
        XCTAssertFalse(app.alerts["Error"].exists, "bookmark creation reported an error")

        app.buttons[AccessibilityId.carPlayToggle].tap()
        openCarTab(app, "Library")
        tapCarCell(app, containing: "Bookmarks")
        let bookmarkRow = carList(app).cells.firstMatch
        XCTAssertTrue(bookmarkRow.waitForExistence(timeout: 15), "bookmark not listed in the car")
        XCTAssertTrue(pollUntil(timeout: 10) { bookmarkRow.isHittable }, "bookmark row is not tappable")
        bookmarkRow.tap()
        if !pollUntil(timeout: 2, { !bookmarkRow.isHittable }), bookmarkRow.isHittable {
            bookmarkRow.tap()
        }
        waitForCarNowPlaying(app)
    }
}
