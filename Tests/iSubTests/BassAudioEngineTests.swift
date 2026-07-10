//
//  BassAudioEngineTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
import AVFAudio
@testable import iSub_Beta

// COV-11: integration tests driving the real BASS boundary with bundled fixture
// audio (MP3 + FLAC to exercise plugin loading). Assertions are on observable
// player/equalizer state, never on audio output.
final class BassAudioEngineTests: StoreTestCase {
    private var player: BassPlayer!
    private var playQueue: PlayQueue!
    private var settings: SavedSettings!

    override func setUpWithError() throws {
        try super.setUpWithError()
        XCTAssertTrue(store.add(server: TestData.server(id: 1)))

        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        settings = freshSettings

        let freshPlayer = BassPlayer(store: store, settings: freshSettings, social: FakeSocial())
        TestContainer.register { freshPlayer }
        TestContainer.register { freshPlayer as PlayerControlling }
        player = freshPlayer

        let fakeDownloadQueue = FakeDownloadQueue()
        TestContainer.register { fakeDownloadQueue as DownloadQueueing }

        let freshStreamManager = StreamManager(store: store,
                                               settings: freshSettings,
                                               player: freshPlayer,
                                               downloadsManager: DownloadsManager(settings: freshSettings, store: store),
                                               networkStatus: FakeNetworkStatus(),
                                               metadataDownloader: FakeSongMetadataDownloader())
        TestContainer.register { freshStreamManager }
        TestContainer.register { freshStreamManager as StreamManaging }

        let freshPlayQueue = makeTestPlayQueue()
        TestContainer.register { freshPlayQueue }
        playQueue = freshPlayQueue

        // Back-edges, exactly as the composition root wires them
        freshStreamManager.attach(downloadQueue: fakeDownloadQueue)
        freshStreamManager.attach(playQueue: freshPlayQueue)
        freshPlayer.attach(playQueue: freshPlayQueue)
        freshPlayer.attach(streamManager: freshStreamManager)
        freshPlayer.attach(downloadQueue: fakeDownloadQueue)

        player.initializeOutput()

        UserDefaults.standard.removeObject(forKey: "BassEffectSelectedPresetId")
        UserDefaults.standard.removeObject(forKey: "BassEffectUserPresets")
    }

    override func tearDownWithError() throws {
        player?.stop()
        UserDefaults.standard.removeObject(forKey: "BassEffectSelectedPresetId")
        UserDefaults.standard.removeObject(forKey: "BassEffectUserPresets")
        player = nil
        playQueue = nil
        settings = nil
        try super.tearDownWithError()
    }

    // Copies a bundled fixture audio file to the song's local path and marks it cached
    private func makeCachedSong(id: String, fixture: String, suffix: String, kiloBitrate: Int = 128, duration: Int = 10) throws -> Song {
        let song = TestData.song(serverId: 1, id: id, title: "Fixture \(id)", path: "Fixtures/\(id).\(suffix)", suffix: suffix, duration: duration, kiloBitrate: kiloBitrate)
        XCTAssertTrue(store.add(song: song))

        let fixtureURL = try Fixtures.url(fixture)
        let destination = URL(fileURLWithPath: song.localPath)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: fixtureURL, to: destination)

        _ = store.add(downloadedSong: DownloadedSong(song: song))
        _ = store.update(downloadFinished: true, song: song)
        XCTAssertTrue(song.isFullyCached)
        return song
    }

    private func queueAndStart(_ song: Song, at index: Int = 0) {
        XCTAssertTrue(store.add(song: song, localPlaylistId: LocalPlaylist.Default.playQueueId))
        playQueue.currentIndex = index
        player.startSong(song, index: index, offsetInBytes: 0, offsetInSeconds: 0)
    }

    @discardableResult
    private func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return condition()
    }

    // MARK: Playback

    func testStartSongCreatesStreamAndPlaysMP3() throws {
        let song = try makeCachedSong(id: "mp3", fixture: "Audio/test_song.mp3", suffix: "mp3", duration: 144)
        queueAndStart(song)

        XCTAssertTrue(waitUntil { self.player.isStarted && self.player.isPlaying }, "the player should start the MP3 stream")
        XCTAssertEqual(player.currentStream?.song, song)
        XCTAssertGreaterThan(player.currentStream?.sampleRate ?? 0, 0, "BASS reports the stream's sample rate")
        XCTAssertGreaterThan(player.currentStream?.channelCount ?? 0, 0)
        XCTAssertTrue(waitUntil { self.player.progress > 0.1 }, "playback progress should advance")
    }

    func testStartSongPlaysFLACViaPluginLoading() throws {
        // Exercises the BASS FLAC plugin: stream creation fails without it
        let song = try makeCachedSong(id: "flac", fixture: "Audio/tone.flac", suffix: "flac", duration: 10)
        queueAndStart(song)

        XCTAssertTrue(waitUntil { self.player.isStarted && self.player.isPlaying }, "the player should start the FLAC stream")
        XCTAssertEqual(player.currentStream?.song, song)
        XCTAssertTrue(waitUntil { self.player.progress > 0.1 }, "FLAC playback progress should advance")
    }

    func testEstimateKiloBitrateForRealStream() throws {
        let song = try makeCachedSong(id: "mp3", fixture: "Audio/test_song.mp3", suffix: "mp3", duration: 144)
        queueAndStart(song)
        XCTAssertTrue(waitUntil { self.player.isPlaying && self.player.progress > 0.2 })

        let stream = try XCTUnwrap(player.currentStream)
        XCTAssertGreaterThan(Bass.estimateKiloBitrate(bassStream: stream), 0, "a decoding stream should produce a bitrate estimate")
    }

    func testPlayPauseTogglesPlaybackState() throws {
        let song = try makeCachedSong(id: "mp3", fixture: "Audio/test_song.mp3", suffix: "mp3", duration: 144)
        queueAndStart(song)
        XCTAssertTrue(waitUntil { self.player.isPlaying })

        player.playPause()
        XCTAssertFalse(player.isPlaying)
        XCTAssertTrue(player.isStarted, "pausing keeps the stream alive")

        player.playPause()
        XCTAssertTrue(player.isPlaying)

        player.pause()
        XCTAssertFalse(player.isPlaying)
        player.pause()
        XCTAssertFalse(player.isPlaying, "pause is idempotent")
    }

    func testStopTearsDownStream() throws {
        let song = try makeCachedSong(id: "mp3", fixture: "Audio/test_song.mp3", suffix: "mp3", duration: 144)
        queueAndStart(song)
        XCTAssertTrue(waitUntil { self.player.isPlaying })

        player.stop()

        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.isStarted, "the stream queue is emptied on stop")
        XCTAssertNil(player.currentStream)
        XCTAssertEqual(player.progress, 0, accuracy: 0.001)
    }

    // MARK: Seeking

    func testSeekToPositionSeconds() throws {
        let song = try makeCachedSong(id: "mp3", fixture: "Audio/test_song.mp3", suffix: "mp3", duration: 144)
        queueAndStart(song)
        XCTAssertTrue(waitUntil { self.player.isPlaying })

        XCTAssertTrue(player.seekToPosition(seconds: 30, fadeVolume: false))
        XCTAssertTrue(waitUntil { self.player.progress >= 30 }, "progress should jump to the seek target")
        XCTAssertGreaterThan(player.startByteOffset, 0, "seeking records the byte offset")
    }

    func testSeekToPositionBytes() throws {
        let song = try makeCachedSong(id: "mp3", fixture: "Audio/test_song.mp3", suffix: "mp3", duration: 144)
        queueAndStart(song)
        XCTAssertTrue(waitUntil { self.player.isPlaying })

        XCTAssertTrue(player.seekToPosition(bytes: 200_000, fadeVolume: false))
        XCTAssertEqual(player.startByteOffset, 200_000)
    }

    func testSeekFailsWithoutStream() {
        XCTAssertFalse(player.seekToPosition(seconds: 5))
        XCTAssertFalse(player.seekToPosition(bytes: 1000))
    }

    // MARK: Underrun handling (BUG-02)

    // Writes only the first `bytes` of the fixture to the song's local path WITHOUT marking
    // the download finished, simulating an in-progress stream download
    private func makePartialSong(id: String, fixture: String, suffix: String, bytes: Int, duration: Int, kiloBitrate: Int = 128) throws -> (song: Song, fullData: Data) {
        let fixtureURL = try Fixtures.url(fixture)
        let fullData = try Data(contentsOf: fixtureURL)
        let song = TestData.song(serverId: 1, id: id, title: "Partial \(id)", path: "Fixtures/\(id).\(suffix)", suffix: suffix, duration: duration, kiloBitrate: kiloBitrate, size: fullData.count)
        XCTAssertTrue(store.add(song: song))

        let destination = URL(fileURLWithPath: song.localPath)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fullData.prefix(bytes).write(to: destination)

        XCTAssertTrue(store.add(downloadedSong: DownloadedSong(song: song)))
        XCTAssertFalse(song.isFullyCached, "the partial song must not be considered fully cached")
        return (song, fullData)
    }

    func testUnderrunPausesThenResumesWhenDataArrives() throws {
        // Only the first few seconds of the 144s MP3 are on disk, so decoding runs dry
        let partialBytes = 96 * 1024
        let (song, fullData) = try makePartialSong(id: "partial", fixture: "Audio/test_song.mp3", suffix: "mp3", bytes: partialBytes, duration: 144)
        queueAndStart(song)

        XCTAssertTrue(waitUntil { self.player.isStarted && self.player.isPlaying }, "playback should start from the partial file")

        // The decoder exhausts the partial file and the player enters the underrun wait loop
        XCTAssertTrue(waitUntil(timeout: 30) { self.player.currentStream?.isWaiting == true }, "the stream should enter the underrun wait state")
        XCTAssertTrue(player.isPlaying, "buffering must not flip the play/pause state")
        let progressWhileWaiting = player.progress

        // "Download" the rest of the file; the wait loop checks the size once per second
        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: song.localPath))
        try handle.seekToEnd()
        try handle.write(contentsOf: fullData.suffix(from: partialBytes))
        try handle.close()
        _ = store.update(downloadFinished: true, song: song)

        XCTAssertTrue(waitUntil(timeout: 15) { self.player.currentStream?.isWaiting == false }, "the wait loop should end once the data arrives")
        XCTAssertTrue(waitUntil(timeout: 15) { self.player.progress > progressWhileWaiting + 0.5 }, "playback should resume and progress should advance")
        XCTAssertNil(player.waitLoopStream, "the wait loop stream reference is cleared")
    }

    func testUnderrunWaitLoopBreaksOnSeek() throws {
        let partialBytes = 96 * 1024
        let (song, _) = try makePartialSong(id: "partialseek", fixture: "Audio/test_song.mp3", suffix: "mp3", bytes: partialBytes, duration: 144)
        queueAndStart(song)

        XCTAssertTrue(waitUntil { self.player.isStarted && self.player.isPlaying }, "playback should start from the partial file")
        XCTAssertTrue(waitUntil(timeout: 30) { self.player.currentStream?.isWaiting == true }, "the stream should enter the underrun wait state")

        // Seeking back into the downloaded part breaks the wait loop
        player.seekToPosition(seconds: 1, fadeVolume: false)
        XCTAssertTrue(waitUntil(timeout: 10) { self.player.currentStream?.isWaiting == false }, "seeking must break the wait loop")
    }

    // MARK: Gapless playback

    func testPrepareNextStreamAndGaplessTransition() throws {
        let first = try makeCachedSong(id: "first", fixture: "Audio/test_song.mp3", suffix: "mp3", duration: 144)
        let second = try makeCachedSong(id: "second", fixture: "Audio/tone.flac", suffix: "flac", duration: 10)
        XCTAssertTrue(store.add(song: first, localPlaylistId: LocalPlaylist.Default.playQueueId))
        XCTAssertTrue(store.add(song: second, localPlaylistId: LocalPlaylist.Default.playQueueId))
        playQueue.currentIndex = 0

        player.startSong(first, index: 0, offsetInBytes: 0, offsetInSeconds: 0)
        XCTAssertTrue(waitUntil { self.player.isPlaying })

        // startSong prepares the next song's stream for gapless playback
        XCTAssertTrue(waitUntil { self.player.streamQueue.count == 2 }, "the next song's stream should be pre-decoded")
        XCTAssertEqual(player.streamQueue.last?.song, second)

        // Simulate the mixer reaching the end of the first stream
        let firstStream = try XCTUnwrap(player.currentStream)
        player.songEnded(bassStream: firstStream)

        XCTAssertTrue(waitUntil { self.playQueue.currentIndex == 1 }, "songEnded advances the play queue")
        XCTAssertTrue(waitUntil { self.player.currentStream?.song == second }, "the prepared stream becomes current")
        XCTAssertTrue(player.isPlaying, "playback continues into the next song")
    }

    // MARK: Equalizer

    private func makeEqValue(frequency: Float, gain: Float = 3.0) -> BASS_DX8_PARAMEQ {
        BASS_DX8_PARAMEQ(fCenter: frequency, fBandwidth: 18, fGain: gain)
    }

    func testApplyAndClearEqualizerValues() {
        let equalizer = player.equalizer
        equalizer.removeAllEqualizerValues()

        equalizer.addEqualizerValue(value: makeEqValue(frequency: 100))
        equalizer.addEqualizerValue(value: makeEqValue(frequency: 1000))
        equalizer.addEqualizerValue(value: makeEqValue(frequency: 10000))
        XCTAssertEqual(equalizer.equalizerValues.count, 3)
        XCTAssertFalse(equalizer.isEqActive, "adding values does not activate the EQ")

        equalizer.applyEqualizerValues()
        XCTAssertTrue(equalizer.isEqActive)
        XCTAssertTrue(equalizer.equalizerValues.allSatisfy { $0.handle != 0 }, "active EQ points hold BASS FX handles")

        equalizer.removeAllEqualizerValues()
        XCTAssertFalse(equalizer.isEqActive)
        XCTAssertEqual(equalizer.equalizerValues.count, 0)
    }

    func testToggleEqualizerActivatesAndDeactivates() {
        let equalizer = player.equalizer
        equalizer.removeAllEqualizerValues()
        equalizer.addEqualizerValue(value: makeEqValue(frequency: 500))

        settings.isEqualizerOn = false
        equalizer.toggleEqualizer()
        XCTAssertTrue(equalizer.isEqActive)
        XCTAssertTrue(settings.isEqualizerOn, "the setting tracks the EQ state")

        equalizer.toggleEqualizer()
        XCTAssertFalse(equalizer.isEqActive)
        XCTAssertFalse(settings.isEqualizerOn)
    }

    func testRemoveEqualizerValueRemovesBand_BUG11() {
        let equalizer = player.equalizer
        equalizer.removeAllEqualizerValues()
        equalizer.addEqualizerValue(value: makeEqValue(frequency: 100))
        let middle = equalizer.addEqualizerValue(value: makeEqValue(frequency: 1000))
        equalizer.addEqualizerValue(value: makeEqValue(frequency: 10000))

        equalizer.removeEqualizerValue(value: middle)

        XCTAssertEqual(equalizer.equalizerValues.count, 2, "removing a band must shrink the EQ")
        XCTAssertEqual(equalizer.equalizerValues.map(\.frequency), [100, 10000], "the middle band must be removed")
        XCTAssertEqual(equalizer.equalizerValues.map(\.arrayIndex), [0, 1], "remaining indexes must be re-sequenced")

        // An out-of-bounds index must be a safe no-op, not a crash
        let stale = BassParamEqValue(parameters: BASS_DX8_PARAMEQ(), arrayIndex: 5)
        equalizer.removeEqualizerValue(value: stale)
        XCTAssertEqual(equalizer.equalizerValues.count, 2, "an out-of-bounds value must not remove anything")
    }

    func testUpdateEqParameter() {
        let equalizer = player.equalizer
        equalizer.removeAllEqualizerValues()
        let value = equalizer.addEqualizerValue(value: makeEqValue(frequency: 100, gain: 0))

        value.gain = 6
        value.frequency = 250
        equalizer.updateEqParameter(value: value)

        XCTAssertEqual(equalizer.equalizerValues[0].gain, 6)
        XCTAssertEqual(equalizer.equalizerValues[0].frequency, 250)
    }

    // MARK: BassEffectDAO presets

    func testEffectDAOLoadsDefaultPresets() {
        let dao = BassEffectDAO(type: .parametricEQ)
        XCTAssertGreaterThan(dao.presets.count, 0, "bundled default presets must load")
        XCTAssertEqual(dao.userPresets.count, 0)
    }

    func testSelectPresetAppliesEQPointsAndPersistsSelection() throws {
        let dao = BassEffectDAO(type: .parametricEQ)
        // Pick a preset with EQ points (index 0 is typically the flat/off preset)
        let index = try XCTUnwrap(dao.presets.firstIndex { !$0.values.isEmpty })
        let preset = dao.presets[index]

        dao.selectPreset(index: index)

        XCTAssertEqual(dao.selectedPresetId, preset.presetId)
        XCTAssertEqual(dao.selectedPresetIndex, index)
        XCTAssertEqual(player.equalizer.equalizerValues.count, preset.values.count, "each preset point becomes an EQ band")

        // Verify the point → frequency/gain transform for the first point
        let point = preset.values[0]
        let expectedFrequency = exp2f((Float(point.x) * Float(RANGE_OF_EXPONENTS)) + 5)
        let expectedGain = Float(0.5 - point.y) * Float(MAX_GAIN * 2)
        XCTAssertEqual(player.equalizer.equalizerValues[0].frequency, expectedFrequency, accuracy: 0.01)
        XCTAssertEqual(player.equalizer.equalizerValues[0].gain, expectedGain, accuracy: 0.01)

        // A fresh DAO reads the persisted selection
        XCTAssertEqual(BassEffectDAO(type: .parametricEQ).selectedPresetId, preset.presetId)
    }

    func testSelectPresetWithInvalidIndexIsIgnored() {
        let dao = BassEffectDAO(type: .parametricEQ)
        let before = dao.selectedPresetId
        dao.selectPreset(index: 999)
        XCTAssertEqual(dao.selectedPresetId, before)
    }

    // MARK: Audio session handling

    // The handlers are invoked directly rather than posting to the notification center:
    // the BASS library registers its own AVAudioSession observers, and hand-crafted
    // notifications crash it with an unrecognized selector, killing the test host

    private func interruptionNotification(type: AVAudioSession.InterruptionType, options: AVAudioSession.InterruptionOptions? = nil) -> Notification {
        // The system delivers the type/options as NSNumber raw values
        var userInfo: [AnyHashable: Any] = [AVAudioSessionInterruptionTypeKey: NSNumber(value: type.rawValue)]
        if let options {
            userInfo[AVAudioSessionInterruptionOptionKey] = NSNumber(value: options.rawValue)
        }
        return Notification(name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(), userInfo: userInfo)
    }

    private func routeChangeNotification(reason: AVAudioSession.RouteChangeReason) -> Notification {
        Notification(name: AVAudioSession.routeChangeNotification,
                     object: AVAudioSession.sharedInstance(),
                     userInfo: [AVAudioSessionRouteChangeReasonKey: NSNumber(value: reason.rawValue)])
    }

    func testInterruptionPausesAndResumesPlayback() throws {
        let song = try makeCachedSong(id: "mp3", fixture: "Audio/test_song.mp3", suffix: "mp3", duration: 144)
        queueAndStart(song)
        XCTAssertTrue(waitUntil { self.player.isPlaying })

        player.handleInterruption(notification: interruptionNotification(type: .began))

        XCTAssertTrue(waitUntil { !self.player.isPlaying }, "an interruption pauses playback")
        XCTAssertTrue(player.shouldResumeFromInterruption)

        player.handleInterruption(notification: interruptionNotification(type: .ended, options: .shouldResume))

        XCTAssertTrue(waitUntil { self.player.isPlaying }, "a should-resume interruption end resumes playback")
        XCTAssertFalse(player.shouldResumeFromInterruption)
    }

    func testInterruptionWhilePausedDoesNotSetResumeFlag() throws {
        let song = try makeCachedSong(id: "mp3", fixture: "Audio/test_song.mp3", suffix: "mp3", duration: 144)
        queueAndStart(song)
        XCTAssertTrue(waitUntil { self.player.isPlaying })
        player.pause()

        player.handleInterruption(notification: interruptionNotification(type: .began))

        XCTAssertFalse(player.shouldResumeFromInterruption, "an interruption while paused must not schedule a resume")
        XCTAssertFalse(player.isPlaying)
    }

    func testRouteChangeToUnavailableDevicePausesPlayback() throws {
        let song = try makeCachedSong(id: "mp3", fixture: "Audio/test_song.mp3", suffix: "mp3", duration: 144)
        queueAndStart(song)
        XCTAssertTrue(waitUntil { self.player.isPlaying })

        player.handleRouteChange(notification: routeChangeNotification(reason: .oldDeviceUnavailable))

        XCTAssertTrue(waitUntil { !self.player.isPlaying }, "unplugging the output device pauses playback")
    }

    func testOtherRouteChangesDoNotPause() throws {
        let song = try makeCachedSong(id: "mp3", fixture: "Audio/test_song.mp3", suffix: "mp3", duration: 144)
        queueAndStart(song)
        XCTAssertTrue(waitUntil { self.player.isPlaying })

        player.handleRouteChange(notification: routeChangeNotification(reason: .newDeviceAvailable))

        XCTAssertTrue(player.isPlaying)
    }
}
