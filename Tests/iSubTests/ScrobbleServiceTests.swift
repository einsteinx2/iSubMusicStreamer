//
//  ScrobbleServiceTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// Phase 8.2: characterizes the scrobble threshold behavior of the old Social
// singleton, now living in ScrobbleRules + ScrobbleService off the audio path.
final class ScrobbleServiceTests: SandboxedTestCase {
    private var session: ServerSession!
    private var settings: SavedSettings!
    private var player: FakePlayer!
    private var service: ScrobbleService!
    // (song, isSubmission) pairs, in submission order
    private var submissions: [(song: Song, isSubmission: Bool)]!

    override func setUpWithError() throws {
        try super.setUpWithError()
        session = ServerSession()
        settings = SavedSettings(session: session)
        player = FakePlayer()
        submissions = []
        service = ScrobbleService(settings: settings, session: session, player: player) { [weak self] song, isSubmission in
            self?.submissions.append((song, isSubmission))
        }
    }

    override func tearDownWithError() throws {
        // Stops the polling timer if a lifecycle test started it
        NotificationCenter.postOnMainThread(name: Notifications.songPlaybackEnded)
        service = nil
        submissions = nil
        player = nil
        settings = nil
        session = nil
        try super.tearDownWithError()
    }

    // MARK: ScrobbleRules (characterized from the old Social.scrobbleDelay)

    func testScrobbleDelayDefaultsTo30SecondsWithoutDuration() {
        XCTAssertEqual(ScrobbleRules.scrobbleDelay(duration: 0, scrobblePercent: 0.5), 30.0)
        XCTAssertEqual(ScrobbleRules.scrobbleDelay(duration: -1, scrobblePercent: 0.5), 30.0)
    }

    func testScrobbleDelayIsPercentOfKnownDuration() {
        XCTAssertEqual(ScrobbleRules.scrobbleDelay(duration: 240, scrobblePercent: 0.5), 120.0)
        XCTAssertEqual(ScrobbleRules.scrobbleDelay(duration: 100, scrobblePercent: 0.75), 75.0, accuracy: 0.0001)
    }

    func testNowPlayingDelayIsTenSeconds() {
        XCTAssertEqual(ScrobbleRules.nowPlayingDelay, 10.0)
    }

    // MARK: Now-playing submission

    func testNowPlayingFiresOnceAtThreshold() {
        let song = TestData.song()

        service.handle(song: song, progress: 5)
        XCTAssertTrue(submissions.isEmpty)

        service.handle(song: song, progress: 10)
        XCTAssertEqual(submissions.count, 1)
        XCTAssertEqual(submissions[0].song, song)
        XCTAssertFalse(submissions[0].isSubmission)

        service.handle(song: song, progress: 20)
        XCTAssertEqual(submissions.count, 1, "now-playing must fire only once per song")
    }

    // MARK: Scrobble submission

    func testScrobbleFiresOnceAtPercentThreshold() {
        settings.isScrobbleEnabled = true
        settings.scrobblePercent = 0.5
        let song = TestData.song(duration: 240) // threshold at 120s

        service.handle(song: song, progress: 119)
        XCTAssertEqual(submissions.count, 1, "only the now-playing submission so far")

        service.handle(song: song, progress: 120)
        XCTAssertEqual(submissions.count, 2)
        XCTAssertTrue(submissions[1].isSubmission)

        service.handle(song: song, progress: 200)
        XCTAssertEqual(submissions.count, 2, "the scrobble must fire only once per song")
    }

    func testScrobbleDisabledSuppressesScrobbleButNotNowPlaying() {
        settings.isScrobbleEnabled = false
        let song = TestData.song(duration: 240)

        service.handle(song: song, progress: 130)

        XCTAssertEqual(submissions.count, 1)
        XCTAssertFalse(submissions[0].isSubmission, "now-playing is not gated on the scrobble setting")
    }

    // MARK: Offline gating (flags still flip at the threshold, matching old Social)

    func testOfflineSuppressesSubmissionsAndFlagsStayConsumed() {
        settings.isScrobbleEnabled = true
        session.isOfflineMode = true
        let song = TestData.song(duration: 240)

        service.handle(song: song, progress: 130)
        XCTAssertTrue(submissions.isEmpty, "offline mode suppresses both submissions")

        // Back online mid-song: the thresholds were already consumed, so nothing
        // fires late — same as the old Social behavior
        session.isOfflineMode = false
        service.handle(song: song, progress: 140)
        XCTAssertTrue(submissions.isEmpty)
    }

    // MARK: Per-song lifecycle resets

    func testPlaybackEndedAndStartedResetsFlagsForRepeatOne() {
        let song = TestData.song()
        service.handle(song: song, progress: 15)
        XCTAssertEqual(submissions.count, 1)

        // Repeat-one: the same song ends and immediately restarts
        NotificationCenter.postOnMainThread(name: Notifications.songPlaybackEnded)
        NotificationCenter.postOnMainThread(name: Notifications.songPlaybackStarted)

        service.handle(song: song, progress: 15)
        XCTAssertEqual(submissions.count, 2, "a restarted song submits now-playing again")
    }

    func testBassFreedResetsFlags() {
        let song = TestData.song()
        service.handle(song: song, progress: 15)
        XCTAssertEqual(submissions.count, 1)

        NotificationCenter.postOnMainThread(name: Notifications.bassFreed)

        service.handle(song: song, progress: 15)
        XCTAssertEqual(submissions.count, 2)
    }

    func testSongIdentityChangeResetsFlags() {
        let songA = TestData.song(id: "1")
        let songB = TestData.song(id: "2")

        service.handle(song: songA, progress: 15)
        XCTAssertEqual(submissions.count, 1)

        // No lifecycle notification arrived, but the song changed under us
        service.handle(song: songB, progress: 15)
        XCTAssertEqual(submissions.count, 2)
        XCTAssertEqual(submissions[1].song, songB)
    }

    func testSameSongIdOnDifferentServerResetsFlags() {
        // Song ids are per-server, so id "1" on server 1 and id "1" on server 2 are
        // different songs — a mixed-server queue must re-arm the submissions
        let songA = TestData.song(serverId: 1, id: "1")
        let songB = TestData.song(serverId: 2, id: "1")

        service.handle(song: songA, progress: 15)
        XCTAssertEqual(submissions.count, 1)

        service.handle(song: songB, progress: 15)
        XCTAssertEqual(submissions.count, 2, "the same song id on a different server is a different song")
        XCTAssertEqual(submissions[1].song, songB)
    }

    func testPauseDoesNotResetFlags() {
        let song = TestData.song()
        service.handle(song: song, progress: 15)
        XCTAssertEqual(submissions.count, 1)

        NotificationCenter.postOnMainThread(name: Notifications.songPlaybackPaused)

        service.handle(song: song, progress: 16)
        XCTAssertEqual(submissions.count, 1, "flags survive a pause, matching the old render-callback behavior")
    }

    func testResumeFromPauseDoesNotRearmSubmissions() {
        settings.isScrobbleEnabled = true
        settings.scrobblePercent = 0.5
        let song = TestData.song(duration: 240)

        // Both thresholds crossed: now-playing + scrobble
        service.handle(song: song, progress: 130)
        XCTAssertEqual(submissions.count, 2)

        // Pause then resume: BassPlayer.playPause() posts songPlaybackStarted again
        // on resume — the per-song flags must survive or the song scrobbles twice
        NotificationCenter.postOnMainThread(name: Notifications.songPlaybackPaused)
        NotificationCenter.postOnMainThread(name: Notifications.songPlaybackStarted)

        service.handle(song: song, progress: 140)
        XCTAssertEqual(submissions.count, 2, "a pause/resume cycle must not re-scrobble the song")
    }

    // MARK: Timer plumbing

    func testPlaybackStartedNotificationStartsThePollingTimerWhichSubmits() throws {
        // The production driver is the songPlaybackStarted notification starting the
        // 5-second polling timer, whose tick reads the player — every other test
        // calls handle() directly, so deleting startTimer() would leave production
        // silent while the suite stayed green
        let song = TestData.song()
        try FileManager.default.createDirectory(atPath: (song.currentPath as NSString).deletingLastPathComponent,
                                                withIntermediateDirectories: true)
        try Data("audio".utf8).write(to: URL(fileURLWithPath: song.currentPath))
        player.currentStream = try XCTUnwrap(BassStream(song: song))
        player.progress = 15

        NotificationCenter.postOnMainThread(name: Notifications.songPlaybackStarted)

        // The first tick fires within the 5s interval (+1s tolerance)
        let deadline = Date(timeIntervalSinceNow: 8)
        while submissions.isEmpty && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        XCTAssertEqual(submissions.count, 1, "the polling timer never ticked a now-playing submission")
        XCTAssertFalse(submissions[0].isSubmission)
    }
}
