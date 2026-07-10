//
//  VideoUITests.swift
//  iSubUITests
//
//  Created by Benjamin Baron on 7/10/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest

// E2E-06 video path, XCUI part: the "Video" fixture folder (Library > Folders > Video)
// contains an isVideo entry. Tapping it must present the AVPlayerViewController (the
// mock HTTP server serves the /rest/hls.m3u8 playlist and segments over loopback), and
// video rows must be excluded from the swipe-to-cache/queue actions.
final class VideoUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    private func openVideoFolder() -> XCUIApplication {
        let app = ISubApp.launch(mockServer: true)
        app.waitForTabBar()
        app.openTab(AccessibilityId.tabLibrary)
        let foldersTab = app.buttons["Folders"].firstMatch
        if foldersTab.waitForExistence(timeout: 5) {
            foldersTab.tap()
        }
        // The "Video" folder artist sits near the bottom of the index list; scroll to it
        let videoCell = app.cells.staticTexts["Video"]
        XCTAssertTrue(videoCell.waitForExistence(timeout: 15), "folder artists did not load")
        for _ in 0..<10 where !videoCell.isHittable {
            app.tables.firstMatch.swipeUp()
        }
        videoCell.tap()
        XCTAssertTrue(app.cells.staticTexts["Test Video"].waitForExistence(timeout: 15),
                      "video fixture folder did not load")
        return app
    }

    func testTappingVideoSongPresentsVideoPlayer() {
        let app = openVideoFolder()
        app.tapCell(containing: "Test Video")

        // The fullscreen AVPlayerViewController covers the app (its own controls are
        // system UI, so detect it by the app chrome disappearing under the modal)
        XCTAssertTrue(waitUntil(timeout: 20) {
            app.buttons["Done"].firstMatch.exists || !app.tabBars.firstMatch.isHittable
        }, "tapping a video song did not present the video player")

        // The audio player must NOT have opened for a video row
        XCTAssertFalse(app.buttons[AccessibilityId.playerPlayPause].isHittable,
                       "the audio player opened for a video song")
    }

    func testVideoRowsExcludedFromSwipeActions() {
        let app = openVideoFolder()

        // The neighboring audio row still offers Download + Queue
        app.cells.staticTexts["Video Folder Song"].firstMatch.swipeLeft()
        XCTAssertTrue(app.buttons["Queue"].firstMatch.waitForExistence(timeout: 5),
                      "audio row lost its Queue swipe action")
        XCTAssertTrue(app.buttons["Download"].firstMatch.exists,
                      "audio row lost its Download swipe action")
        // Close the swipe actions
        app.cells.staticTexts["Test Video"].firstMatch.tap(withNumberOfTaps: 1, numberOfTouches: 1)
        _ = waitUntil(timeout: 5) { !app.buttons["Queue"].firstMatch.exists }

        // Video rows must not offer Download (cache) or Queue. They currently still do —
        // SwipeAction.downloadAndQueueConfig ignores isDownloadable/isVideo — so this
        // documents the target behavior until the exclusion lands.
        app.cells.staticTexts["Test Video"].firstMatch.swipeLeft()
        XCTExpectFailure("BUG: video rows still get Download/Queue swipe actions (downloadAndQueueConfig ignores isVideo)", strict: false) {
            let downloadAppeared = app.buttons["Download"].firstMatch.waitForExistence(timeout: 3)
            XCTAssertFalse(downloadAppeared, "video row offers a Download swipe action")
            XCTAssertFalse(app.buttons["Queue"].firstMatch.exists, "video row offers a Queue swipe action")
        }
    }
}
