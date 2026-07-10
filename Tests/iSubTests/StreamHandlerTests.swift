//
//  StreamHandlerTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// Records StreamHandler delegate callbacks and exposes expectations for them
final class StreamHandlerDelegateSpy: StreamHandlerDelegate {
    let startedExpectation = XCTestExpectation(description: "streamHandlerStarted")
    let startPlaybackExpectation = XCTestExpectation(description: "streamHandlerStartPlayback")
    let finishedExpectation = XCTestExpectation(description: "streamHandlerConnectionFinished")
    let failedExpectation = XCTestExpectation(description: "streamHandlerConnectionFailed")

    private(set) var startedCount = 0
    private(set) var startPlaybackCount = 0
    private(set) var finishedCount = 0
    private(set) var failures = [Error]()

    func streamHandlerStarted(handler: StreamHandler) {
        startedCount += 1
        startedExpectation.fulfill()
    }

    func streamHandlerStartPlayback(handler: StreamHandler) {
        startPlaybackCount += 1
        startPlaybackExpectation.fulfill()
    }

    func streamHandlerConnectionFinished(handler: StreamHandler) {
        finishedCount += 1
        finishedExpectation.fulfill()
    }

    func streamHandlerConnectionFailed(handler: StreamHandler, error: Error) {
        failures.append(error)
        failedExpectation.fulfill()
    }
}

// COV-08: StreamHandler behavior against the mock server — file writing, resume
// offsets, byte-threshold playback notification (BUG-03 gate), content-length
// verification, and the Codable persistence round-trip.
final class StreamHandlerTests: StoreTestCase {
    private var delegateSpy: StreamHandlerDelegateSpy!
    private var activeHandler: StreamHandler?

    override func setUpWithError() throws {
        try super.setUpWithError()
        MockSubsonicServer.install()
        XCTAssertTrue(store.add(server: TestData.server(id: 1, urlString: "https://mock.example.com")))
        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        let freshPlayQueue = PlayQueue()
        TestContainer.register { freshPlayQueue }
        delegateSpy = StreamHandlerDelegateSpy()
    }

    override func tearDownWithError() throws {
        activeHandler?.cancel()
        activeHandler = nil
        delegateSpy = nil
        MockSubsonicServer.uninstall()
        try super.tearDownWithError()
    }

    private func makeSong(id: String = "77", kiloBitrate: Int = 128) -> Song {
        let song = TestData.song(serverId: 1, id: id, title: "Streamed", path: "Artist/Album/\(id).mp3", kiloBitrate: kiloBitrate)
        _ = store.add(song: song)
        return song
    }

    // The Codable path requires Dependencies in the decoder's userInfo (production
    // sets it in StreamManager.loadHandlerStack)
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.userInfo[.streamHandlerDependencies] = StreamHandler.Dependencies.fromResolver()
        return decoder
    }

    func testDownloadWritesFileAndAddsDownloadedSongRow() throws {
        let body = Data((0..<5000).map { UInt8($0 % 256) })
        MockSubsonicServer.stub(.stream, data: body, contentType: "audio/mpeg")
        let song = makeSong()

        let handler = StreamHandler(song: song, tempCache: false, delegate: delegateSpy, dependencies: .fromResolver())
        activeHandler = handler
        handler.start()

        wait(for: [delegateSpy.startedExpectation, delegateSpy.finishedExpectation], timeout: 10)

        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: song.localPath)), body, "the streamed bytes must land at the song's local path")
        XCTAssertEqual(handler.totalBytesTransferred, body.count)
        XCTAssertFalse(handler.isDownloading, "download finished")
        XCTAssertNotNil(store.downloadedSong(serverId: 1, songId: "77"), "a downloadedSong row is created for permanent downloads")
        // Completion always notifies playback start
        XCTAssertTrue(handler.isDelegateNotifiedToStartPlayback)

        let received = try XCTUnwrap(MockSubsonicServer.receivedRequests(action: .stream).first)
        XCTAssertEqual(received.parameter("id"), "77")
        XCTAssertEqual(received.parameter("estimateContentLength"), "1")
        XCTAssertNil(received.request.value(forHTTPHeaderField: "Range"), "no range header without a byte offset")
    }

    func testNewDownloadFileIsExcludedFromBackupWhenBackupCacheDisabled() throws {
        // isBackupCacheEnabled defaults to false, so freshly created download files
        // must carry the backup-exclusion flag (it is never inherited) — STUB-06
        MockSubsonicServer.stub(.stream, data: Data(repeating: 7, count: 1000), contentType: "audio/mpeg")
        let song = makeSong()

        let handler = StreamHandler(song: song, tempCache: false, delegate: delegateSpy, dependencies: .fromResolver())
        activeHandler = handler
        handler.start()
        wait(for: [delegateSpy.finishedExpectation], timeout: 10)

        let values = try URL(fileURLWithPath: song.localPath).resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }

    func testTempCacheDownloadWritesToTempPathWithoutDownloadRow() throws {
        let body = Data(repeating: 7, count: 3000)
        MockSubsonicServer.stub(.stream, data: body, contentType: "audio/mpeg")
        let song = makeSong(id: "78")

        let handler = StreamHandler(song: song, tempCache: true, delegate: delegateSpy, dependencies: .fromResolver())
        activeHandler = handler
        handler.start()

        wait(for: [delegateSpy.finishedExpectation], timeout: 10)

        XCTAssertTrue(FileManager.default.fileExists(atPath: song.localTempPath), "temp downloads go to the temp path")
        XCTAssertFalse(FileManager.default.fileExists(atPath: song.localPath))
        XCTAssertNil(store.downloadedSong(serverId: 1, songId: "78"), "temp downloads must not create downloadedSong rows")
    }

    func testResumeSeeksToEndAndSendsRangeHeader() throws {
        let song = makeSong(id: "79")
        // Simulate a partial download on disk
        let existing = Data(repeating: 1, count: 4096)
        try FileManager.default.createDirectory(atPath: (song.localPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try existing.write(to: URL(fileURLWithPath: song.localPath))

        MockSubsonicServer.stub(.stream, data: Data(repeating: 2, count: 2000), contentType: "audio/mpeg")

        let handler = StreamHandler(song: song, tempCache: false, delegate: delegateSpy, dependencies: .fromResolver())
        activeHandler = handler
        handler.start(resume: true)

        wait(for: [delegateSpy.finishedExpectation], timeout: 10)

        XCTAssertEqual(handler.byteOffset, 4096, "byte offset advances to the existing file size")
        let received = try XCTUnwrap(MockSubsonicServer.receivedRequests(action: .stream).first)
        XCTAssertEqual(received.request.value(forHTTPHeaderField: "Range"), "bytes=4096-")
        // The new bytes are appended after the existing ones
        let fileData = try Data(contentsOf: URL(fileURLWithPath: song.localPath))
        XCTAssertEqual(fileData.count, 4096 + 2000)
    }

    func testStartPlaybackNotifiedDuringDownloadForLowBitrateSong() {
        // Positive control for the threshold gate: with a very low bitrate song, the
        // stalled download far exceeds the playback threshold, so the playback
        // notification fires mid-download
        let song = makeSong(id: "80", kiloBitrate: 8) // 10s = 10,240 bytes
        MockSubsonicServer.stubStalling(.stream, data: Data(repeating: 3, count: 100_000))

        let handler = StreamHandler(song: song, tempCache: false, delegate: delegateSpy, dependencies: .fromResolver())
        activeHandler = handler
        handler.start()

        wait(for: [delegateSpy.startPlaybackExpectation], timeout: 10)
        XCTAssertEqual(delegateSpy.startPlaybackCount, 1)
        XCTAssertTrue(handler.isDelegateNotifiedToStartPlayback)
    }

    func testStartPlaybackNotifiedAfterTenSecondsOfAudio_BUG03() {
        // BUG-03 regression: the start-playback gate must use the ~10s
        // minBytesToStartPlayback threshold, not the 60s limiting threshold.
        // Buffer 30s worth of a 128 Kbps song mid-download: playback should start.
        let song = makeSong(id: "81", kiloBitrate: 128) // 10s = 163,840 bytes; 60s = 983,040
        MockSubsonicServer.stubStalling(.stream, data: Data(repeating: 3, count: 500_000))

        let handler = StreamHandler(song: song, tempCache: false, delegate: delegateSpy, dependencies: .fromResolver())
        activeHandler = handler
        handler.start()

        let result = XCTWaiter.wait(for: [delegateSpy.startPlaybackExpectation], timeout: 2)
        XCTAssertEqual(result, .completed, "playback should be told to start after ~10 seconds of audio is buffered")
    }

    func testThrottlingDelaysDownloadWhileSongPlays_BUG04() throws {
        // Throttling only engages while a song is actively playing
        let fakePlayer = FakePlayer()
        fakePlayer.isPlaying = true
        TestContainer.register { fakePlayer as PlayerControlling }

        // 128 Kbps song: throttling starts after 983,040 bytes (60s of audio); the wifi
        // cap is ~100 KB per 0.1s interval (~1 MB/s). Deliver ~1.4 MB at ~3 MB/s so the
        // transfer runs well over the cap once past the threshold.
        let song = makeSong(id: "84", kiloBitrate: 128)
        let body = Data(repeating: 6, count: 1_400_000)
        MockSubsonicServer.stubChunked(.stream, data: body, chunkSize: 64 * 1024, chunkDelay: 0.02)

        let handler = StreamHandler(song: song, tempCache: false, delegate: delegateSpy, dependencies: .fromResolver())
        activeHandler = handler
        handler.start()

        wait(for: [delegateSpy.finishedExpectation], timeout: 30)

        XCTAssertGreaterThan(handler.throttleCount, 0, "the transfer should have been throttled at least once")
        let fileData = try Data(contentsOf: URL(fileURLWithPath: song.localPath))
        XCTAssertEqual(fileData.count, body.count, "throttling must not lose data")
    }

    func testNoThrottlingWhenNothingIsPlaying() throws {
        let fakePlayer = FakePlayer()
        fakePlayer.isPlaying = false
        TestContainer.register { fakePlayer as PlayerControlling }

        let song = makeSong(id: "85", kiloBitrate: 128)
        let body = Data(repeating: 6, count: 1_400_000)
        MockSubsonicServer.stubChunked(.stream, data: body, chunkSize: 64 * 1024, chunkDelay: 0.02)

        let handler = StreamHandler(song: song, tempCache: false, delegate: delegateSpy, dependencies: .fromResolver())
        activeHandler = handler
        handler.start()

        wait(for: [delegateSpy.finishedExpectation], timeout: 30)

        XCTAssertEqual(handler.throttleCount, 0, "downloads run at full speed when no song is playing")
        let fileData = try Data(contentsOf: URL(fileURLWithPath: song.localPath))
        XCTAssertEqual(fileData.count, body.count)
    }

    func testContentLengthShortfallFailsInsteadOfFinishing() {
        // Advertise more bytes than are delivered: the handler must treat the early
        // completion as a failure so the download is retried, never a clean finish
        let song = makeSong(id: "82")
        MockSubsonicServer.stub(.stream) { _ in
            MockSubsonicServer.StubResponse(headers: ["Content-Type": "audio/mpeg", "Content-Length": "1000000"], body: Data(repeating: 4, count: 10_000))
        }

        let handler = StreamHandler(song: song, tempCache: false, delegate: delegateSpy, dependencies: .fromResolver())
        activeHandler = handler
        handler.start()

        wait(for: [delegateSpy.failedExpectation], timeout: 10)
        XCTAssertFalse(handler.isDownloading)
        XCTAssertEqual(delegateSpy.finishedCount, 0, "a shortfall is a failure, never also a clean finish")
    }

    func testServerErrorStatusCodeFailsDownload_BUG15() {
        // A 5xx must surface as a connection failure so delegates retry/remove, not
        // silently complete
        let song = makeSong(id: "85")
        MockSubsonicServer.stub(.stream, data: Data("Internal Server Error".utf8), statusCode: 500, contentType: "text/html")

        let handler = StreamHandler(song: song, tempCache: false, delegate: delegateSpy, dependencies: .fromResolver())
        activeHandler = handler
        handler.start()

        wait(for: [delegateSpy.failedExpectation], timeout: 10)
        XCTAssertFalse(handler.isDownloading)
        XCTAssertEqual(delegateSpy.finishedCount, 0, "a 5xx must never look like a clean finish")
        XCTAssertEqual(delegateSpy.failures.count, 1, "the failure is reported exactly once")
        XCTAssertFalse(delegateSpy.failures[0].isCanceled, "the failure must not be reported as a local cancellation")
    }

    func testCancelStopsDownload() {
        let song = makeSong(id: "83")
        MockSubsonicServer.stubStalling(.stream, data: Data(repeating: 5, count: 200_000))

        let handler = StreamHandler(song: song, tempCache: false, delegate: delegateSpy, dependencies: .fromResolver())
        activeHandler = handler
        handler.start()
        wait(for: [delegateSpy.startedExpectation], timeout: 10)
        XCTAssertTrue(handler.isDownloading)

        handler.cancel()

        XCTAssertFalse(handler.isDownloading)
        XCTAssertEqual(delegateSpy.finishedCount, 0)

        // A local cancellation must not surface as a connection failure either, or the
        // delegate would schedule a retry of the download it just canceled
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1))
        XCTAssertTrue(delegateSpy.failures.isEmpty, "cancel() must not trigger the failure/retry path")
    }

    func testCodableRoundTrip() throws {
        let song = makeSong(id: "84")
        let handler = StreamHandler(song: song, byteOffset: 1234, secondsOffset: 56.5, tempCache: true, delegate: delegateSpy, dependencies: .fromResolver())

        let data = try JSONEncoder().encode(handler)
        let decoded = try makeDecoder().decode(StreamHandler.self, from: data)

        XCTAssertEqual(decoded.song, song, "the song is rehydrated from the store by serverId+songId")
        XCTAssertEqual(decoded.byteOffset, 1234)
        XCTAssertEqual(decoded.secondsOffset, 56.5, accuracy: 0.001)
        XCTAssertTrue(decoded.isTempCache)
        XCTAssertFalse(decoded.isDownloading)
        XCTAssertFalse(decoded.isDelegateNotifiedToStartPlayback)
    }

    func testCodableDecodePreservesInFlightState() throws {
        let song = makeSong(id: "85")
        _ = song // ensure the song row exists for rehydration
        let json = """
            {"serverId": 1, "songId": "85", "byteOffset": 999, "secondsOffset": 12.25,
             "isDelegateNotifiedToStartPlayback": true, "isTempCache": false,
             "isDownloading": true, "contentLength": 555555, "maxBitrateSetting": 160}
            """
        let decoded = try makeDecoder().decode(StreamHandler.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.song.id, "85")
        XCTAssertEqual(decoded.byteOffset, 999)
        XCTAssertTrue(decoded.isDelegateNotifiedToStartPlayback)
        XCTAssertTrue(decoded.isDownloading, "in-flight state survives so downloads resume after relaunch")
    }

    func testCodableDecodeFailsForUnknownSong() {
        let json = #"{"serverId": 1, "songId": "does-not-exist", "byteOffset": 0, "secondsOffset": 0, "isDelegateNotifiedToStartPlayback": false, "isTempCache": false, "isDownloading": false}"#
        XCTAssertThrowsError(try makeDecoder().decode(StreamHandler.self, from: Data(json.utf8)))
    }
}
