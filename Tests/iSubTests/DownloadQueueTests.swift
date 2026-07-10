//
//  DownloadQueueTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// COV-08: DownloadQueue state machine — start/stop, offline and gating rules,
// handler stealing from the StreamManager, and download completion bookkeeping.
// The BUG-05 inverted stop() guard is gated with XCTExpectFailure.
final class DownloadQueueTests: StoreTestCase {
    private var downloadQueue: DownloadQueue!
    private var streamManager: FakeStreamManager!
    private var settings: SavedSettings!

    override func setUpWithError() throws {
        try super.setUpWithError()
        MockSubsonicServer.install()
        XCTAssertTrue(store.add(server: TestData.server(id: 1, urlString: "https://mock.example.com")))

        streamManager = FakeStreamManager()
        let fakeStreamManager = streamManager!
        TestContainer.register { fakeStreamManager as StreamManaging }
        TestContainer.register { FakePlayer() as PlayerControlling }

        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        settings = freshSettings
        // Allow downloading regardless of the simulator's reported network type
        settings.isManualCachingOnWWANEnabled = true

        let freshPlayQueue = PlayQueue()
        TestContainer.register { freshPlayQueue }

        downloadQueue = DownloadQueue()
    }

    override func tearDownWithError() throws {
        downloadQueue?.currentStreamHandler?.cancel()
        downloadQueue = nil
        streamManager = nil
        settings = nil
        MockSubsonicServer.uninstall()
        try super.tearDownWithError()
    }

    private func makeQueuedSong(id: String, isVideo: Bool = false) -> Song {
        let song = TestData.song(serverId: 1, id: id, title: "Song \(id)", path: "Artist/Album/\(id).mp3", isVideo: isVideo)
        _ = store.add(song: song)
        XCTAssertTrue(store.addToDownloadQueue(serverId: 1, songId: id))
        return song
    }

    @discardableResult
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return condition()
    }

    // MARK: start gating

    func testStartWithEmptyQueueDoesNothing() {
        downloadQueue.start()
        XCTAssertFalse(downloadQueue.isDownloading)
        XCTAssertNil(downloadQueue.currentStreamHandler)
    }

    func testStartInOfflineModeDoesNotDownload() {
        _ = makeQueuedSong(id: "1")
        settings.isOfflineMode = true

        downloadQueue.start()

        XCTAssertFalse(downloadQueue.isDownloading)
        XCTAssertNil(downloadQueue.currentStreamHandler)
        XCTAssertEqual(MockSubsonicServer.receivedRequests.count, 0)
    }

    func testStartRemovesVideoSongsFromQueue() {
        _ = makeQueuedSong(id: "1", isVideo: true)

        downloadQueue.start()

        XCTAssertFalse(downloadQueue.isDownloading)
        XCTAssertEqual(store.downloadQueueCount(), 0, "videos are dropped from the download queue")
    }

    func testStartRemovesAlreadyCachedSongs() {
        let song = makeQueuedSong(id: "1")
        _ = store.add(downloadedSong: DownloadedSong(song: song))
        _ = store.update(downloadFinished: true, song: song)

        let downloadedExpectation = expectation(forNotification: Notifications.downloadQueueSongDownloaded, object: nil, handler: nil)
        downloadQueue.start()
        wait(for: [downloadedExpectation], timeout: 5)

        XCTAssertEqual(store.downloadQueueCount(), 0, "already-cached songs are cleared from the queue")
        XCTAssertFalse(downloadQueue.isDownloading)
    }

    // MARK: Downloading

    func testStartDownloadsAndMarksSongFinished() {
        MockSubsonicServer.stub(.stream, data: Data(repeating: 1, count: 5000), contentType: "audio/mpeg")
        let song = makeQueuedSong(id: "1")

        let downloadedExpectation = expectation(forNotification: Notifications.downloadQueueSongDownloaded, object: nil, handler: nil)
        let startedExpectation = expectation(forNotification: Notifications.downloadQueueStarted, object: nil, handler: nil)
        downloadQueue.start()
        wait(for: [startedExpectation, downloadedExpectation], timeout: 10)

        XCTAssertTrue(store.isDownloadFinished(song: song), "the finished download is marked cached")
        XCTAssertEqual(store.downloadQueueCount(), 0, "the finished download leaves the queue")
        XCTAssertTrue(waitUntil { !self.downloadQueue.isDownloading }, "the queue goes idle once drained")
        XCTAssertTrue(FileManager.default.fileExists(atPath: song.localPath))
    }

    func testStartStealsHandlerFromStreamManager() {
        MockSubsonicServer.stubStalling(.stream, data: Data(repeating: 1, count: 10_000))
        let song = makeQueuedSong(id: "1")

        // The stream manager already has a handler for this song
        let handler = StreamHandler(song: song, tempCache: false, delegate: StreamHandlerDelegateSpy())
        streamManager.handlersBySong[song] = handler

        downloadQueue.start()

        XCTAssertTrue(downloadQueue.isDownloading)
        XCTAssertTrue(streamManager.stolenHandlers.contains(handler), "the existing stream handler is stolen instead of duplicated")
        XCTAssertTrue(downloadQueue.currentStreamHandler === handler)
        XCTAssertTrue(waitUntil { handler.isDownloading }, "the stolen handler is resumed")
    }

    // MARK: stop (BUG-05)

    func testStopCancelsActiveDownload_BUG05() {
        MockSubsonicServer.stubStalling(.stream, data: Data(repeating: 1, count: 100_000))
        _ = makeQueuedSong(id: "1")

        downloadQueue.start()
        XCTAssertTrue(downloadQueue.isDownloading)
        let handler = downloadQueue.currentStreamHandler

        downloadQueue.stop()

        XCTExpectFailure("BUG-05: stop() has an inverted guard and returns while downloading; remove this marker when fixing the bug") {
            XCTAssertFalse(downloadQueue.isDownloading, "stop() must cancel an in-flight download")
            XCTAssertNil(downloadQueue.currentStreamHandler)
            XCTAssertEqual(handler?.isDownloading, false, "the active stream handler must be cancelled")
        }
    }

    func testStopWhenIdlePostsStoppedNotification() {
        // With nothing downloading, the (inverted) guard passes and stop() runs
        let stoppedExpectation = expectation(forNotification: Notifications.downloadQueueStopped, object: nil, handler: nil)
        downloadQueue.stop()
        wait(for: [stoppedExpectation], timeout: 5)
        XCTAssertFalse(downloadQueue.isDownloading)
    }

    // MARK: removeCurrentSong / clear

    func testRemoveCurrentSongRemovesQueueRowAndContinues() {
        MockSubsonicServer.stubStalling(.stream, data: Data(repeating: 1, count: 100_000))
        let song = makeQueuedSong(id: "1")

        downloadQueue.start()
        XCTAssertTrue(downloadQueue.isDownloading)
        let handler = downloadQueue.currentStreamHandler

        XCTAssertTrue(downloadQueue.removeCurrentSong())
        XCTAssertFalse(store.isSongInDownloadQueue(song: song), "the active song leaves the queue")

        // Cleanup: BUG-05 means the in-flight handler wasn't cancelled by stop()
        handler?.cancel()
    }

    func testClearEmptiesQueue() {
        _ = makeQueuedSong(id: "1")
        _ = makeQueuedSong(id: "2")

        XCTAssertTrue(downloadQueue.clear())

        XCTAssertEqual(store.downloadQueueCount(), 0)
    }

    // MARK: Queue introspection

    func testIsInQueueAndCurrentQueuedSongInDb() {
        let song = makeQueuedSong(id: "1")
        XCTAssertTrue(downloadQueue.isInQueue(song: song))
        XCTAssertEqual(downloadQueue.currentQueuedSongInDb, song)

        let notQueued = TestData.song(serverId: 1, id: "99", path: "a/99.mp3")
        XCTAssertFalse(downloadQueue.isInQueue(song: notQueued))
    }
}
