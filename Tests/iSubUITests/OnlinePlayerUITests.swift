//
//  OnlinePlayerUITests.swift
//  iSubUITests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// E2E-02 Player tab: transport controls, ±30s quick skip, seeking (incl. past the cached
// point via -SLOWDOWNLOAD), repeat cycling, shuffle toggle refreshing the queue view,
// bookmark creation, page control paging, EQ open/toggle/preset flows, and landscape.
// Playback runs against the embedded mock HTTP server with real audio bytes.
//
// Lock-screen remote commands (MPRemoteCommandCenter) aren't reachable from XCUITest;
// that path is covered by the audio-engine integration tests.
final class OnlinePlayerUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
        try super.tearDownWithError()
    }

    private func launchPlaying(slowDownload: Bool = false) -> XCUIApplication {
        let app = ISubApp.launch(mockServer: true, slowDownload: slowDownload)
        app.waitForTabBar()
        app.startPlaybackViaServerShuffle()
        return app
    }

    private func sliderValue(_ app: XCUIApplication) -> Double {
        let slider = app.sliders[AccessibilityId.playerSeekSlider]
        let value = slider.value as? String ?? "0%"
        return Double(value.replacingOccurrences(of: "%", with: "")) ?? 0
    }

    // Flips the Enable Jukebox Mode toggle in Settings > Playback and returns to the tab bar
    private func toggleJukeboxSetting(in app: XCUIApplication) {
        app.openTab(AccessibilityId.tabSettings)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        app.buttons["settings.section.playback"].tap()
        XCTAssertTrue(app.navigationBars["Playback"].waitForExistence(timeout: 10))
        app.tapToggle(AccessibilityId.optionsEnableJukebox)

        // Section screens hide the tab bar, so pop back to the settings root first
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.tabBars.buttons[AccessibilityId.tabPlayer].waitForExistence(timeout: 10),
                      "tab bar did not reappear on the settings root")
    }

    func testJukeboxButtonGatedBySettingAndTogglesMode() {
        let app = ISubApp.launch(mockServer: true)
        app.waitForTabBar()

        // Hidden until the Enable Jukebox Mode setting is turned on. The queue is empty
        // here on purpose: the toggle must work without any songs queued.
        app.openTab(AccessibilityId.tabPlayer)
        XCTAssertFalse(app.buttons[AccessibilityId.playerJukebox].exists,
                       "jukebox button is visible without the setting enabled")

        toggleJukeboxSetting(in: app)

        app.openTab(AccessibilityId.tabPlayer)
        let jukeboxButton = app.buttons[AccessibilityId.playerJukebox]
        XCTAssertTrue(jukeboxButton.waitForExistence(timeout: 10),
                      "jukebox button did not appear after enabling the setting")

        // Toggling on swaps in the jukebox volume slider; off removes it
        jukeboxButton.tap()
        let volumeSlider = app.sliders[AccessibilityId.playerJukeboxVolume]
        XCTAssertTrue(volumeSlider.waitForExistence(timeout: 10), "jukebox mode did not activate")
        jukeboxButton.tap()
        XCTAssertTrue(waitUntil(timeout: 10) { !volumeSlider.exists }, "jukebox mode did not deactivate")

        // Turning the setting off while the mode is active exits jukebox mode too,
        // otherwise playback would silently stay routed to the server
        jukeboxButton.tap()
        XCTAssertTrue(volumeSlider.waitForExistence(timeout: 10))
        toggleJukeboxSetting(in: app)
        app.openTab(AccessibilityId.tabPlayer)
        XCTAssertTrue(waitUntil(timeout: 10) { !volumeSlider.exists },
                      "disabling the setting did not exit jukebox mode")
        XCTAssertTrue(waitUntil(timeout: 10) { !app.buttons[AccessibilityId.playerJukebox].exists },
                      "jukebox button still visible with the setting disabled")
    }

    func testTransportPlayPauseNextPrevious() {
        let app = launchPlaying()

        // Playback progresses
        XCTAssertTrue(waitUntil(timeout: 20) { self.sliderValue(app) > 0 }, "playback did not start")

        // Pause freezes the progress, play resumes it
        app.buttons[AccessibilityId.playerPlayPause].tap()
        let paused = sliderValue(app)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
        XCTAssertEqual(sliderValue(app), paused, accuracy: 1.5, "progress moved while paused")
        app.buttons[AccessibilityId.playerPlayPause].tap()
        XCTAssertTrue(waitUntil(timeout: 10) { self.sliderValue(app) > paused + 0.5 }, "playback did not resume")

        // Next then previous actually move through the queue (the shuffled fixture
        // queue has 10 distinct songs, so the title must change and change back)
        let title = app.staticTexts[AccessibilityId.playerSongTitle].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "no song title on the player")
        let firstTitle = title.label
        app.buttons[AccessibilityId.playerNext].tap()
        XCTAssertTrue(waitUntil(timeout: 20) { title.label != firstTitle },
                      "next did not advance to a different song")
        app.buttons[AccessibilityId.playerPrevious].tap()
        XCTAssertTrue(waitUntil(timeout: 20) { title.label == firstTitle },
                      "previous did not return to the original song")
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 10))
    }

    func testQuickSkipForwardAndBack() {
        let app = launchPlaying()
        XCTAssertTrue(waitUntil(timeout: 20) { self.sliderValue(app) > 0 }, "playback did not start")

        // +30s: the fixture song is ~146s, so a skip lands around 20%
        let before = sliderValue(app)
        app.buttons[AccessibilityId.playerQuickSkipForward].tap()
        XCTAssertTrue(waitUntil(timeout: 10) { self.sliderValue(app) > before + 10 },
                      "quick skip forward did not jump ahead")

        // -30s returns near the start
        app.buttons[AccessibilityId.playerQuickSkipBack].tap()
        XCTAssertTrue(waitUntil(timeout: 10) { self.sliderValue(app) < 15 },
                      "quick skip back did not jump back")
    }

    func testSeekWithinSongAndPastCachePoint() {
        // Slow downloads keep the transfer in-flight so seeking ahead crosses the cache point
        let app = launchPlaying(slowDownload: true)
        XCTAssertTrue(waitUntil(timeout: 30) { self.sliderValue(app) > 0 }, "playback did not start")

        // Seek within the buffered part. Like the past-cache-point drag below, the
        // XCUISlider drag sometimes drops its touches, so retry until the value sticks.
        let slider = app.sliders[AccessibilityId.playerSeekSlider]
        var withinSeekLanded = false
        for _ in 0..<5 where !withinSeekLanded {
            slider.adjust(toNormalizedSliderPosition: 0.15)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.0))
            withinSeekLanded = sliderValue(app) > 5
        }
        XCTAssertTrue(withinSeekLanded, "seek within song failed")

        // Seek far past what has downloaded; the player must survive, and playback should
        // recover by restarting the stream at the new offset (BUG-02 regression: the
        // underrun wait loop in BassPlayer.pauseIfUnderrun handles running dry).
        // XCUISlider drags sometimes fail to deliver their touch events to the live
        // slider (the thumb snaps back to the playing position), so only accept a
        // seek whose value sticks, retrying the drag otherwise.
        var seekLanded = false
        for _ in 0..<5 where !seekLanded {
            slider.adjust(toNormalizedSliderPosition: 0.9)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.0))
            seekLanded = sliderValue(app) > 70
        }
        XCTAssertTrue(seekLanded, "could not drag the seek slider past the cache point")
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 10))
        // The fixture's metadata duration (4:03/8MB) doesn't match its actual audio
        // (~584KB), so a deep slider seek lands past the real EOF and playback
        // position is not meaningful here (progress-based recovery assertions can't
        // work — see docs/REVIEW_FINDINGS_2026-07-12.md). What BUG-02 guarantees is
        // that running dry at the seek point never wedges the player: the underrun
        // wait loop must break for transport commands, so Next must still advance
        // the queue.
        let title = app.staticTexts[AccessibilityId.playerSongTitle].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "no song title on the player")
        let stuckTitle = title.label
        app.buttons[AccessibilityId.playerNext].tap()
        XCTAssertTrue(waitUntil(timeout: 20) { title.label != stuckTitle },
                      "the player wedged after seeking past the cache point (BUG-02)")
    }

    func testRepeatModeCycling() {
        let app = launchPlaying()
        XCTAssertTrue(waitUntil(timeout: 20) { self.sliderValue(app) > 0 }, "playback did not start")

        let repeatButton = app.buttons[AccessibilityId.playerRepeat]
        repeatButton.tap() // none -> one
        repeatButton.tap() // one -> all
        repeatButton.tap() // all -> none

        // Survive past the 3.3s save-state timer (BUG-01 regression: saveState used to
        // crash writing the RepeatMode enum raw to UserDefaults)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 5))
        XCTAssertTrue(app.buttons[AccessibilityId.playerRepeat].exists,
                      "app crashed after cycling repeat mode (BUG-01)")
    }

    // A queue row's combined text, used to detect order changes
    private func queueRowText(_ app: XCUIApplication, index: Int) -> String {
        let cell = app.tables.firstMatch.cells.element(boundBy: index)
        return cell.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "|")
    }

    func testShuffleToggleRefreshesQueueView() {
        let app = launchPlaying()

        // Snapshot the top of the original queue before shuffling
        app.openTab(AccessibilityId.tabPlaylists)
        let countLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] '10 song'")).firstMatch
        XCTAssertTrue(countLabel.waitForExistence(timeout: 15), "queue view did not load")
        let originalRows = (0..<3).map { queueRowText(app, index: $0) }

        // Shuffle on
        app.openTab(AccessibilityId.tabPlayer)
        app.buttons[AccessibilityId.playerShuffle].tap()
        XCTAssertTrue(app.buttons[AccessibilityId.playerShuffle].waitForExistence(timeout: 15))

        // The queue view still lists the songs (reshuffled order, same count)
        app.openTab(AccessibilityId.tabPlaylists)
        XCTAssertTrue(countLabel.waitForExistence(timeout: 15), "queue view did not refresh after shuffle")

        // Shuffle off restores the original queue ORDER, not just the count — a
        // broken unshuffle used to pass when only the count label was checked
        app.openTab(AccessibilityId.tabPlayer)
        app.buttons[AccessibilityId.playerShuffle].tap()
        app.openTab(AccessibilityId.tabPlaylists)
        XCTAssertTrue(countLabel.waitForExistence(timeout: 15), "queue view did not refresh after unshuffle")
        XCTAssertTrue(waitUntil(timeout: 10) { (0..<3).map { self.queueRowText(app, index: $0) } == originalRows },
                      "unshuffle did not restore the original queue order")
    }

    func testBookmarkCreation() {
        let app = launchPlaying()

        app.tapExpectingAlert(button: AccessibilityId.playerBookmarks, alertTitle: "Create Bookmark")
        app.fillAlert(titled: "Create Bookmark", text: "Player Bookmark", confirm: "Save")

        // No error alert means the bookmark saved; verify it listed under Library > Bookmarks
        XCTAssertFalse(app.alerts["Error"].exists, "bookmark creation reported an error")
        app.openTab(AccessibilityId.tabLibrary)
        app.buttons["Bookmarks"].firstMatch.tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15), "created bookmark not listed")
    }

    func testPageControlPaging() {
        let app = launchPlaying()

        let pageControl = app.pageIndicators[AccessibilityId.playerPageControl]
        XCTAssertTrue(pageControl.waitForExistence(timeout: 10), "player page control missing")

        // Swiping the cover art area pages between cover art / song info / lyrics / downloads
        XCTAssertTrue((pageControl.value as? String)?.hasPrefix("page 1") ?? false)
        app.scrollViews.firstMatch.swipeLeft()
        XCTAssertTrue(waitUntil(timeout: 5) { (pageControl.value as? String)?.hasPrefix("page 2") ?? false },
                      "swiping did not change the player page")
        app.scrollViews.firstMatch.swipeRight()
        XCTAssertTrue(waitUntil(timeout: 5) { (pageControl.value as? String)?.hasPrefix("page 1") ?? false },
                      "swiping back did not return to the cover art page")
    }

    // Dismisses the EQ screen's one-time instructions alert if it is showing
    private func dismissEqualizerInstructions(_ app: XCUIApplication) {
        let alert = app.alerts["Instructions"]
        if alert.waitForExistence(timeout: 3), alert.buttons["Cancel"].exists {
            alert.buttons["Cancel"].tap()
        }
    }

    func testLandscapeAndEqualizerFlows() {
        let app = launchPlaying()

        // Open the equalizer from the player (portrait keeps the frame-based XIB layout
        // intact; the screen is also reachable in landscape)
        let equalizerButton = app.buttons[AccessibilityId.playerEqualizer]
        XCTAssertTrue(equalizerButton.waitForExistence(timeout: 10), "equalizer button missing")
        XCTAssertTrue(waitUntil(timeout: 10) { equalizerButton.isHittable })
        equalizerButton.tap()

        let toggle = app.buttons[AccessibilityId.equalizerToggle]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "equalizer screen did not open")
        dismissEqualizerInstructions(app)

        // BUG-13 regression: no save-preset dialog may auto-appear after opening the EQ
        // (a debug leftover fired promptToSaveCustomPreset 2s after viewDidAppear)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 3))
        XCTAssertFalse(app.alerts["Create Preset"].exists, "the save-preset alert must not auto-appear")
        XCTAssertFalse(app.staticTexts["Choose Preset To Save"].exists, "the save-preset dialog must not auto-appear")

        // Switch presets first: tapping the preset label reveals the picker. This also
        // loads EQ values, which the on/off toggle below needs (with an empty value set
        // BassEqualizer never activates and the toggle sticks).
        app.staticTexts[AccessibilityId.equalizerPresetLabel].tap()
        let pickerWheel = app.pickerWheels.firstMatch
        XCTAssertTrue(pickerWheel.waitForExistence(timeout: 5), "preset picker did not appear")
        pickerWheel.adjust(toPickerWheelValue: "Rock")
        XCTAssertTrue(waitUntil(timeout: 5) { app.staticTexts[AccessibilityId.equalizerPresetLabel].label == "Rock" },
                      "picking a preset did not update the selection")
        // The picker dismisses by tapping the EQ view area above it
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        XCTAssertTrue(waitUntil(timeout: 5) { !pickerWheel.isHittable }, "preset picker did not dismiss")

        // Toggle the EQ off/on ("EQ is ON" <-> "EQ is OFF")
        let initialLabel = toggle.label
        toggle.tap()
        XCTAssertTrue(waitUntil(timeout: 5) { toggle.label != initialLabel }, "EQ toggle did not change state")
        toggle.tap()
        XCTAssertTrue(waitUntil(timeout: 5) { toggle.label == initialLabel }, "EQ toggle did not change back")

        // Double-tap creates an EQ point -> temp custom preset -> Save button appears
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.3)).doubleTap()
        let saveButton = app.buttons[AccessibilityId.equalizerSavePreset]
        XCTAssertTrue(waitUntil(timeout: 10) { saveButton.isHittable }, "editing a point did not offer to save a preset")
        saveButton.tap()
        app.fillAlert(titled: "Create Preset", text: "UITest Preset", confirm: "Save")

        // The saved preset is selected and deletable
        let deleteButton = app.buttons[AccessibilityId.equalizerDeletePreset]
        XCTAssertTrue(waitUntil(timeout: 10) { deleteButton.isHittable }, "saved preset is not deletable")
        deleteButton.tap()
        let confirmAlert = app.alerts.firstMatch
        XCTAssertTrue(confirmAlert.waitForExistence(timeout: 5), "no delete confirmation")
        confirmAlert.buttons["Delete"].tap()

        // Landscape shows the fullscreen visualizer; round-trip the rotation
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(waitUntil(timeout: 10) {
            let frame = app.windows.firstMatch.frame
            return frame.width > frame.height
        }, "the app did not rotate to landscape")

        // BUG-12 regression: swiping the fullscreen visualizer cycles the visualizer type
        // (the recognizers used to target the class instead of the instance and never fired)
        let visualizer = app.otherElements[AccessibilityId.equalizerVisualizer]
        XCTAssertTrue(visualizer.waitForExistence(timeout: 5), "visualizer view missing in landscape")
        let typeBeforeSwipe = visualizer.value as? String
        visualizer.swipeLeft()
        XCTAssertTrue(waitUntil(timeout: 5) { (visualizer.value as? String) != typeBeforeSwipe },
                      "swiping left did not cycle the visualizer type")
        visualizer.swipeRight()
        XCTAssertTrue(waitUntil(timeout: 5) { (visualizer.value as? String) == typeBeforeSwipe },
                      "swiping right did not cycle the visualizer type back")

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(waitUntil(timeout: 10) {
            let frame = app.windows.firstMatch.frame
            return frame.height > frame.width
        }, "the app did not rotate back to portrait")

        // Leave the EQ (nav bar is visible in portrait) and confirm the player survived
        let close = app.buttons[AccessibilityId.equalizerClose]
        if close.exists && close.isHittable {
            close.tap()
        } else {
            app.navigationBars.buttons.firstMatch.tap()
        }
        XCTAssertTrue(app.buttons[AccessibilityId.playerPlayPause].waitForExistence(timeout: 10),
                      "player did not recover after the landscape/EQ round trip")
    }
}
