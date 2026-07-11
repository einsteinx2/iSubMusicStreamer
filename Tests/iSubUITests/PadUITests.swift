//
//  PadUITests.swift
//  iSubUITests
//
//  Created by Benjamin Baron on 7/10/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// E2E-05 iPad split view: PadRootViewController hosts a persistent menu column
// (PadMenuViewController — menu rows plus the embedded player) next to a swappable
// detail pane. The suite verifies each menu item swaps the detail controller,
// drill-down and the navigation back button work inside the detail pane, offline mode
// shows the downloaded content, and the embedded player plays.
//
// The whole suite skips itself on iPhone destinations — run it with an iPad simulator:
//   xcodebuild test -project iSub.xcodeproj -scheme "iSub Beta" \
//     -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' \
//     -only-testing:iSubUITests/PadUITests
final class PadUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad,
                          "PadUITests requires an iPad simulator destination")
    }

    private func launchPad(mode: String? = nil, mockServer: Bool = false, resetState: Bool = true) -> XCUIApplication {
        let app = ISubApp.launch(mode: mode, mockServer: mockServer, resetState: resetState)
        XCTAssertTrue(app.cells[AccessibilityId.padMenuLibrary].waitForExistence(timeout: 30),
                      "iPad menu did not appear")
        return app
    }

    private func tapMenuItem(_ identifier: String, in app: XCUIApplication,
                             file: StaticString = #filePath, line: UInt = #line) {
        let cell = app.cells[identifier]
        XCTAssertTrue(cell.waitForExistence(timeout: 10), "menu item \(identifier) missing", file: file, line: line)
        cell.tap()
    }

    private func sliderValue(_ app: XCUIApplication) -> Double {
        let value = app.sliders[AccessibilityId.playerSeekSlider].value as? String ?? "0%"
        return Double(value.replacingOccurrences(of: "%", with: "")) ?? 0
    }

    func testMenuSwapsDetailControllers() {
        let app = launchPad()

        // The first load lands on Library
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 15),
                      "iPad did not land on the Library detail controller")

        // Each menu item swaps in its detail controller
        tapMenuItem(AccessibilityId.padMenuPlaylists, in: app)
        XCTAssertTrue(app.navigationBars["Playlists"].waitForExistence(timeout: 10),
                      "Playlists menu item did not swap the detail controller")

        tapMenuItem(AccessibilityId.padMenuDownloads, in: app)
        XCTAssertTrue(app.navigationBars["Downloads"].waitForExistence(timeout: 10),
                      "Downloads menu item did not swap the detail controller")

        tapMenuItem(AccessibilityId.padMenuSettings, in: app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10),
                      "Settings menu item did not swap the detail controller")

        tapMenuItem(AccessibilityId.padMenuLibrary, in: app)
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 10),
                      "Library menu item did not swap the detail controller back")
    }

    func testDetailDrillDownAndBackButton() {
        let app = launchPad()

        // Drill into the folder hierarchy in the detail pane
        tapMenuItem(AccessibilityId.padMenuLibrary, in: app)
        app.tapCell(containing: "Beck")
        XCTAssertTrue(app.cells.staticTexts["Odeley"].waitForExistence(timeout: 15),
                      "detail drill-down did not load the artist folder")

        // The navigation back button pops the detail pane back to the artist list
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.cells.staticTexts["Beck"].waitForExistence(timeout: 10),
                      "back button did not return to the folder artists list")

        // The menu column stays in place through the drill-down
        XCTAssertTrue(app.cells[AccessibilityId.padMenuSettings].exists, "menu column disappeared during drill-down")
    }

    func testEmbeddedPlayerPlays() {
        let app = launchPad(mockServer: true)

        // The player is embedded in the menu column, always visible
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 10),
                      "embedded player transport missing from the menu column")

        // Play All from the folder hierarchy starts real playback in the embedded player
        tapMenuItem(AccessibilityId.padMenuLibrary, in: app)
        app.tapCell(containing: "Beck")
        XCTAssertTrue(app.cells.staticTexts["Odeley"].waitForExistence(timeout: 15))
        app.buttons["Play All"].firstMatch.tap()
        XCTAssertTrue(waitUntil(timeout: 30) { self.sliderValue(app) > 0 },
                      "the embedded player did not start playing")
    }

    func testOfflineModeShowsDownloadedContent() {
        // Phase 1 (online, mock server): download the two fixture songs via the detail pane
        var app = launchPad(mockServer: true)
        tapMenuItem(AccessibilityId.padMenuLibrary, in: app)
        app.tapCell(containing: "Beck")
        app.tapCell(containing: "Odeley")
        app.tapCell(containing: "Disc 1")
        XCTAssertTrue(app.cells.staticTexts["MP3 Song"].waitForExistence(timeout: 15),
                      "fixture songs did not load")
        app.swipeAction("Download", onCellContaining: "MP3 Song")
        app.swipeAction("Download", onCellContaining: "FLAC Tone")

        // The download queue starts on app activation
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.cells[AccessibilityId.padMenuDownloads].waitForExistence(timeout: 10))

        tapMenuItem(AccessibilityId.padMenuDownloads, in: app)
        app.buttons["Songs"].firstMatch.tap()
        XCTAssertTrue(app.cells.staticTexts["MP3 Song"].waitForExistence(timeout: 60),
                      "downloaded MP3 did not appear in the Songs sub-tab")
        XCTAssertTrue(app.cells.staticTexts["FLAC Tone"].waitForExistence(timeout: 60),
                      "downloaded FLAC did not appear in the Songs sub-tab")

        // Phase 2: relaunch offline; the menu still works and Downloads shows the content
        app.terminate()
        app = launchPad(mode: "offline", resetState: false)

        tapMenuItem(AccessibilityId.padMenuDownloads, in: app)
        app.buttons["Songs"].firstMatch.tap()
        XCTAssertTrue(app.cells.staticTexts["MP3 Song"].waitForExistence(timeout: 15),
                      "downloaded songs missing from the offline Downloads screen")

        // Playing a downloaded song starts the embedded player offline
        app.tapCell(containing: "MP3 Song")
        XCTAssertTrue(waitUntil(timeout: 30) { self.sliderValue(app) > 0 },
                      "offline playback did not start in the embedded player")

        // Settings stays reachable offline
        tapMenuItem(AccessibilityId.padMenuSettings, in: app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10),
                      "settings not reachable offline on iPad")
    }
}
