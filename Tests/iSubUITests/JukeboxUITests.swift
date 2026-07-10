//
//  JukeboxUITests.swift
//  iSubUITests
//
//  Created by Benjamin Baron on 7/10/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// E2E-04 Jukebox mode: launched with -MODE jukebox and -REQUESTLOG so every stubbed
// request the app makes is recorded to a file this process can read. The suite asserts
// the jukebox UI state (Home toggle label, player volume slider) and that playback
// entry points — Home server shuffle, search-result playback, Folders play-all/shuffle,
// and the Playlists queue — issue jukeboxControl requests to drive the remote player
// instead of streaming locally.
final class JukeboxUITests: XCTestCase {
    private var requestLogPath: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        // The app process appends one line per request; unique per test
        requestLogPath = NSTemporaryDirectory() + "jukebox-requests-\(UUID().uuidString).log"
    }

    override func tearDownWithError() throws {
        if let requestLogPath {
            try? FileManager.default.removeItem(atPath: requestLogPath)
        }
        try super.tearDownWithError()
    }

    private func launchJukebox() -> XCUIApplication {
        let app = ISubApp.launch(mode: "jukebox", extraArguments: ["-REQUESTLOG", requestLogPath])
        app.waitForTabBar()
        return app
    }

    // One "action?key=value&..." line per request the app made
    private func loggedRequests() -> [String] {
        guard let contents = try? String(contentsOfFile: requestLogPath, encoding: .utf8) else { return [] }
        return contents.split(separator: "\n").map(String.init)
    }

    // The jukeboxControl action values in request order (get, set, add, skip, ...)
    private func jukeboxActions() -> [String] {
        loggedRequests().compactMap { line in
            guard line.hasPrefix("jukeboxControl?") else { return nil }
            for pair in line.dropFirst("jukeboxControl?".count).components(separatedBy: "&") {
                let parts = pair.components(separatedBy: "=")
                if parts.first == "action", parts.count > 1 {
                    return parts[1]
                }
            }
            return nil
        }
    }

    // Any local streaming/downloading the app should NOT be doing in jukebox mode
    private func streamRequests() -> [String] {
        loggedRequests().filter { $0.hasPrefix("stream?") || $0.hasPrefix("download?") }
    }

    @discardableResult
    private func waitForJukeboxAction(_ action: String, timeout: TimeInterval = 15,
                                      file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let found = waitUntil(timeout: timeout) { self.jukeboxActions().contains(action) }
        if !found {
            // Show what the app actually requested to make failures diagnosable
            XCTContext.runActivity(named: "request log") { _ in
                add(XCTAttachment(string: loggedRequests().joined(separator: "\n")))
            }
            print("[JukeboxUITests] jukebox action '\(action)' not found; logged requests:\n\(loggedRequests().joined(separator: "\n"))")
        }
        return found
    }

    func testJukeboxUIStateAndRemoteVolume() {
        let app = launchJukebox()

        // Home reflects the enabled state
        XCTAssertTrue(app.staticTexts["Jukebox\nMode is ON"].waitForExistence(timeout: 10),
                      "home jukebox button does not show Mode is ON")

        // The player swaps in the jukebox volume slider and polls the remote status
        app.openTab(AccessibilityId.tabPlayer)
        let volumeSlider = app.sliders[AccessibilityId.playerJukeboxVolume]
        XCTAssertTrue(volumeSlider.waitForExistence(timeout: 10), "jukebox volume slider missing from the player")
        XCTAssertTrue(waitForJukeboxAction("get"), "opening the player did not poll jukebox status")

        // Moving the volume slider drives the remote gain
        volumeSlider.adjust(toNormalizedSliderPosition: 0.8)
        XCTAssertTrue(waitForJukeboxAction("setGain"), "volume slider did not send a setGain jukebox request")

        XCTAssertEqual(streamRequests(), [], "jukebox mode made local stream requests")
    }

    func testServerShuffleIssuesJukeboxCallsInsteadOfStreams() {
        let app = launchJukebox()

        // No media folders are cached on a fresh launch, so the shuffle starts immediately
        app.buttons[AccessibilityId.homeServerShuffle].tap()
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 30),
                      "server shuffle did not land on the player")

        // Starting playback drives the remote jukebox rather than a local stream
        XCTAssertTrue(waitForJukeboxAction("skip"), "server shuffle did not send a jukebox skip/play request")
        XCTAssertEqual(streamRequests(), [], "server shuffle streamed locally despite jukebox mode")

        // The remote playlist should also be replaced with the shuffled songs; the
        // server-shuffle path never syncs it (only skip is sent), so the remote box
        // plays stale content — documents the gap until the sync lands
        XCTExpectFailure("BUG: server shuffle in jukebox mode never syncs the remote playlist (no clear/add sent)", strict: false) {
            XCTAssertTrue(waitForJukeboxAction("add", timeout: 5),
                          "server shuffle did not add the shuffled songs to the remote jukebox playlist")
        }
    }

    func testSearchResultPlaybackIssuesJukeboxCall() {
        let app = launchJukebox()

        let searchBar = app.otherElements[AccessibilityId.homeSearchBar].firstMatch
        let searchField = searchBar.exists ? searchBar : app.searchFields.firstMatch
        searchField.tap()
        app.typeText("beck\n")

        XCTAssertTrue(app.cells.staticTexts["Beck"].waitForExistence(timeout: 15),
                      "search results did not load")
        app.buttons["Songs"].firstMatch.tap()
        app.tapCell(containing: "Novacane")

        // Playing a search result must drive the jukebox. It currently does nothing at
        // all (same root cause as the online suite: search results are never persisted
        // to the store, so playback can't resolve the song).
        XCTExpectFailure("BUG: search results are not persisted to the store, so playing one silently fails", strict: false) {
            XCTAssertTrue(waitForJukeboxAction("skip", timeout: 10),
                          "playing a search result did not send a jukebox request")
        }
        XCTAssertEqual(streamRequests(), [], "search result playback streamed locally despite jukebox mode")
    }

    func testFolderPlayAllAndShuffleIssueJukeboxCalls() {
        let app = launchJukebox()

        // Folders > artist > Play All queues recursively then starts the jukebox:
        // clear (playlist reset) + add (the loaded songs) + skip (start position)
        app.openTab(AccessibilityId.tabLibrary)
        app.tapCell(containing: "Beck")
        XCTAssertTrue(app.cells.staticTexts["Odeley"].waitForExistence(timeout: 15), "artist folder did not load")
        app.buttons["Play All"].firstMatch.tap()
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 30),
                      "play-all did not open the player")
        XCTAssertTrue(waitForJukeboxAction("clear"), "play-all did not clear the remote jukebox playlist")
        XCTAssertTrue(waitForJukeboxAction("add"), "play-all did not add songs to the remote jukebox playlist")
        XCTAssertTrue(waitForJukeboxAction("skip"), "play-all did not start jukebox playback")
        XCTAssertEqual(streamRequests(), [], "play-all streamed locally despite jukebox mode")

        // Shuffle at the artist level re-syncs the remote playlist with the shuffled order
        let addsBeforeShuffle = jukeboxActions().filter { $0 == "add" }.count
        app.openTab(AccessibilityId.tabLibrary)
        XCTAssertTrue(app.buttons["Shuffle"].firstMatch.waitForExistence(timeout: 10),
                      "no Shuffle header at artist level")
        app.buttons["Shuffle"].firstMatch.tap()
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 30),
                      "shuffle did not open the player")
        XCTAssertTrue(waitUntil(timeout: 15) {
            self.jukeboxActions().filter { $0 == "add" }.count > addsBeforeShuffle
        }, "shuffle did not re-add the shuffled songs to the remote jukebox playlist")
        XCTAssertEqual(streamRequests(), [], "shuffle streamed locally despite jukebox mode")
    }

    func testPlaylistsQueueAndPlayUnderJukeboxMode() {
        let app = launchJukebox()

        // Queue the two fixture songs; in jukebox mode they land in the dedicated
        // jukebox play queue playlist
        app.drillToFixtureSongs()
        app.swipeAction("Queue", onCellContaining: "MP3 Song")
        app.swipeAction("Queue", onCellContaining: "FLAC Tone")

        app.openTab(AccessibilityId.tabPlaylists)
        let table = app.tables.firstMatch
        XCTAssertTrue(waitUntil(timeout: 15) { table.cells.count == 2 },
                      "queued songs did not reach the jukebox play queue")

        // Playing a row from the queue drives the jukebox (the queue survives the
        // periodic getInfo refresh since BUG-31 persists the songs' metadata)
        table.cells.element(boundBy: 0).tap()
        XCTAssertTrue(waitForJukeboxAction("skip"), "playing from the queue did not send a jukebox request")
        XCTAssertEqual(streamRequests(), [], "playing from the queue streamed locally despite jukebox mode")
    }
}
