//
//  UITestHelpers.swift
//  iSubUITests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// Shared launch + interaction helpers for the E2E suites. See docs/UI_TESTING.md for
// the launch argument contract.
enum ISubApp {
    // Launches with the URLProtocol fixture stub (any server URL is intercepted).
    // Pass mockServer: true to serve fixtures + real audio over loopback HTTP instead,
    // which makes streaming/downloading behave like production.
    static func launch(mode: String? = nil, fixtures: String? = nil, mockServer: Bool = false,
                       slowDownload: Bool = false, resetState: Bool = true, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITEST"]
        if resetState {
            app.launchArguments.append("-RESET_STATE")
        }
        if mockServer {
            app.launchArguments.append("-MOCKSERVER")
        }
        if slowDownload {
            app.launchArguments.append("-SLOWDOWNLOAD")
        }
        if let mode {
            app.launchArguments += ["-MODE", mode]
        }
        if let fixtures {
            app.launchArguments += ["-FIXTURES", fixtures]
        }
        app.launchArguments += extraArguments
        app.launch()
        return app
    }
}

// Polls a condition until it's true or the timeout elapses
@discardableResult
func pollUntil(timeout: TimeInterval = 15, _ condition: () -> Bool) -> Bool {
    let deadline = Date(timeIntervalSinceNow: timeout)
    while Date() < deadline {
        if condition() { return true }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.25))
    }
    return condition()
}

extension XCTestCase {
    @discardableResult
    func waitUntil(timeout: TimeInterval = 15, _ condition: () -> Bool) -> Bool {
        pollUntil(timeout: timeout, condition)
    }
}

extension XCUIApplication {
    @discardableResult
    func waitForTabBar(file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let exists = tabBars.buttons[AccessibilityId.tabLibrary].waitForExistence(timeout: 30)
        XCTAssertTrue(exists, "app did not reach the root tab bar", file: file, line: line)
        return exists
    }

    func openTab(_ identifier: String) {
        let button = tabBars.buttons[identifier]
        button.tap()
        // A tap can get swallowed by a HUD/transition overlay; retry until selected
        if !pollUntil(timeout: 5, { button.isSelected }) {
            button.tap()
            _ = pollUntil(timeout: 5) { button.isSelected }
        }
    }

    // Taps a SwiftUI Toggle row by its accessibility identifier. The identified switch
    // element spans the whole row (label + switch), and a center tap lands on the
    // label, which doesn't toggle — tap the nested switch when it's exposed, else the
    // trailing edge where the switch control lives.
    func tapToggle(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = switches[identifier].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 10), "no toggle '\(identifier)'", file: file, line: line)
        if !element.isHittable {
            swipeUp()
        }
        let inner = element.switches.firstMatch
        if inner.exists && inner.isHittable {
            inner.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
    }

    // Taps a row by the visible text inside it (UniversalTableViewCell exposes its
    // labels as static texts). Waits for hittability too — paged containers (Tabman)
    // keep neighboring pages in the hierarchy, so existence alone isn't tappable.
    func tapCell(containing text: String, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) {
        let element = cells.staticTexts[text].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "no cell containing '\(text)'", file: file, line: line)
        XCTAssertTrue(pollUntil(timeout: 10) { element.isHittable }, "cell containing '\(text)' is not tappable", file: file, line: line)
        element.tap()
    }

    func cell(containing text: String) -> XCUIElement {
        cells.containing(.staticText, identifier: nil)
            .containing(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    // The first visible non-empty text in a table row (auto-scrolling labels report
    // zero-width empty siblings that aren't tappable)
    var firstCellText: XCUIElement {
        cells.staticTexts.matching(NSPredicate(format: "label != ''")).firstMatch
    }

    func tapFirstCellText(timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) {
        let element = firstCellText
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "no non-empty cell text", file: file, line: line)
        XCTAssertTrue(pollUntil(timeout: 10) { element.isHittable }, "first cell text not tappable", file: file, line: line)
        element.tap()
    }

    // Reveals and taps a trailing swipe action on the first cell containing the text
    func swipeAction(_ actionTitle: String, onCellContaining text: String,
                     file: StaticString = #filePath, line: UInt = #line) {
        let target = cells.staticTexts[text].firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 15), "no cell containing '\(text)'", file: file, line: line)
        XCTAssertTrue(pollUntil(timeout: 10) { target.isHittable }, "cell containing '\(text)' is not swipeable", file: file, line: line)
        target.swipeLeft()
        let action = buttons[actionTitle].firstMatch
        XCTAssertTrue(action.waitForExistence(timeout: 5), "no '\(actionTitle)' swipe action", file: file, line: line)
        action.tap()
    }

    // Fills the single text field of the presented alert and taps the given button
    func fillAlert(titled title: String, text: String, confirm: String,
                   file: StaticString = #filePath, line: UInt = #line) {
        let alert = alerts[title]
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "alert '\(title)' did not appear", file: file, line: line)
        let textField = alert.textFields.firstMatch
        textField.tap()
        textField.typeText(text)
        alert.buttons[confirm].tap()
    }

    // Opens the Library tab's Browse page (quick albums, shuffle all, now playing, ...)
    func openBrowsePage(file: StaticString = #filePath, line: UInt = #line) {
        openTab(AccessibilityId.tabLibrary)
        let browseTab = buttons["Browse"].firstMatch
        XCTAssertTrue(browseTab.waitForExistence(timeout: 10), "no Browse page button in Library", file: file, line: line)
        browseTab.tap()
        XCTAssertTrue(cells[AccessibilityId.browseShuffleAll].waitForExistence(timeout: 10),
                      "Browse page rows did not appear", file: file, line: line)
    }

    // Starts playback via Library > Browse > Shuffle All (10 fixture songs) and waits
    // for the player
    func startPlaybackViaServerShuffle(file: StaticString = #filePath, line: UInt = #line) {
        openBrowsePage(file: file, line: line)
        let shuffleRow = cells[AccessibilityId.browseShuffleAll].firstMatch
        XCTAssertTrue(pollUntil(timeout: 10) { shuffleRow.isHittable }, "shuffle all row is not tappable", file: file, line: line)
        shuffleRow.tap()
        // With multiple media folders cached a folder-picker sheet appears first
        let allFolders = sheets.buttons["All Media Folders"]
        if allFolders.waitForExistence(timeout: 2) {
            allFolders.tap()
        }
        XCTAssertTrue(buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 30),
                      "server shuffle did not land on the player", file: file, line: line)
    }

    // The download queue only starts on a server check (app activation) or from the
    // Downloads screens, so briefly background + foreground the app to kick it off
    func triggerDownloadQueueStart() {
        XCUIDevice.shared.press(.home)
        activate()
        _ = tabBars.firstMatch.waitForExistence(timeout: 10)
    }

    // Drills Library > Folders > Beck > Odeley > Disc 1, the fixture path that ends in
    // real playable songs (FLAC Tone / MP3 Song)
    func drillToFixtureSongs(file: StaticString = #filePath, line: UInt = #line) {
        openTab(AccessibilityId.tabLibrary)
        let foldersTab = buttons["Folders"].firstMatch
        if foldersTab.waitForExistence(timeout: 5) {
            foldersTab.tap()
        }
        tapCell(containing: "Beck", file: file, line: line)
        tapCell(containing: "Odeley", file: file, line: line)
        tapCell(containing: "Disc 1", file: file, line: line)
        XCTAssertTrue(cells.staticTexts["MP3 Song"].waitForExistence(timeout: 15),
                      "fixture songs did not load", file: file, line: line)
    }
}
