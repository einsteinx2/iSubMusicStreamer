//
//  DownloadQueueTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// COV-08: the permanent download lane's state machine — start/stop, offline and
// gating rules, handler promotion from the stream lane, and download completion
// bookkeeping. Drives the DownloadEngine (which absorbed the old DownloadQueue).
final class DownloadQueueTests: StoreTestCase {
    private var downloadQueue: DownloadEngine!
    private var settings: SavedSettings!
    private var network: FakeNetworkStatus!
    private var player: FakePlayer!
    private var downloadsManager: DownloadsManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        MockSubsonicServer.install()
        XCTAssertTrue(store.add(server: TestData.server(id: 1, urlString: "https://mock.example.com")))

        player = FakePlayer()
        let fakePlayer = player!
        TestContainer.register { fakePlayer as PlayerControlling }

        // Deterministic network state regardless of the simulator's actual connection
        network = FakeNetworkStatus()
        let fakeNetwork = network!
        TestContainer.register { fakeNetwork as NetworkStatus }

        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        settings = freshSettings

        let freshPlayQueue = makeTestPlayQueue()
        TestContainer.register { freshPlayQueue }

        downloadsManager = DownloadsManager(settings: settings, store: store)
        downloadQueue = makeDownloadEngine(downloadsManager: downloadsManager)
    }

    // Builds a DownloadEngine wired to this test's fakes (the composition root's job
    // in production); its stream lane is a real StreamManager over the same fakes
    private func makeDownloadEngine(downloadsManager: DownloadsManager) -> DownloadEngine {
        DownloadEngine(store: store,
                       settings: settings,
                       downloadsManager: downloadsManager,
                       player: player,
                       networkStatus: network,
                       metadataDownloader: FakeSongMetadataDownloader())
    }

    override func tearDownWithError() throws {
        downloadQueue?.currentStreamHandler?.cancel()
        downloadQueue = nil
        settings = nil
        network = nil
        player = nil
        downloadsManager = nil
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

    func testStartOnCellularWithoutManualCachingDoesNotDownload() {
        _ = makeQueuedSong(id: "1")
        network.isWifi = false
        settings.isManualCachingOnWWANEnabled = false

        downloadQueue.start()

        XCTAssertFalse(downloadQueue.isDownloading, "cellular downloads are gated behind the manual caching setting")
        XCTAssertNil(downloadQueue.currentStreamHandler)
        XCTAssertEqual(MockSubsonicServer.receivedRequests.count, 0)
    }

    func testStartOnCellularWithManualCachingDownloads() {
        MockSubsonicServer.stubStalling(.stream, data: Data(repeating: 1, count: 100_000))
        _ = makeQueuedSong(id: "1")
        network.isWifi = false
        settings.isManualCachingOnWWANEnabled = true

        downloadQueue.start()

        XCTAssertTrue(downloadQueue.isDownloading, "manual caching on WWAN allows cellular downloads")
        XCTAssertNotNil(downloadQueue.currentStreamHandler)
    }

    func testStartOnWifiDownloadsWithoutManualCaching() {
        MockSubsonicServer.stubStalling(.stream, data: Data(repeating: 1, count: 100_000))
        _ = makeQueuedSong(id: "1")
        network.isWifi = true
        settings.isManualCachingOnWWANEnabled = false

        downloadQueue.start()

        XCTAssertTrue(downloadQueue.isDownloading, "wifi downloads need no extra setting")
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

    func testStartHaltsAndAlertsWhenLowOnDiskSpace_STUB07() {
        // Stubs the free-space check and records the user-facing message
        final class LowSpaceDownloadsManager: DownloadsManager {
            var stubbedFreeSpace = 10 * 1024 * 1024 // below the 25MB floor
            private(set) var noFreeSpaceMessageCount = 0
            override var freeSpace: Int { stubbedFreeSpace }
            override func showNoFreeSpaceMessage() { noFreeSpaceMessageCount += 1 }
        }
        let lowSpaceManager = LowSpaceDownloadsManager(settings: settings, store: store)
        let queue = makeDownloadEngine(downloadsManager: lowSpaceManager)
        _ = makeQueuedSong(id: "1")

        queue.start()

        XCTAssertFalse(queue.isDownloading, "the queue must halt when low on space")
        XCTAssertNil(queue.currentStreamHandler)
        XCTAssertTrue(waitUntil { lowSpaceManager.noFreeSpaceMessageCount == 1 },
                      "the user must be told the device is out of space")

        // With space available again the same start call proceeds
        lowSpaceManager.stubbedFreeSpace = 100 * 1024 * 1024
        MockSubsonicServer.stub(.stream, data: Data(repeating: 1, count: 5000), contentType: "audio/mpeg")
        queue.start()
        XCTAssertTrue(queue.isDownloading)
        XCTAssertEqual(lowSpaceManager.noFreeSpaceMessageCount, 1, "no repeat alert once space is available")
        queue.currentStreamHandler?.cancel()
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

    func testStartPromotesHandlerFromStreamLane() {
        MockSubsonicServer.stubStalling(.stream, data: Data(repeating: 1, count: 10_000))
        let song = makeQueuedSong(id: "1")

        // The stream lane already has a handler for this song
        let streamManager = downloadQueue.streamManager
        streamManager.queueStream(song: song, tempCache: false, startDownload: false)
        let handler = try! XCTUnwrap(streamManager.handler(song: song))

        downloadQueue.start()

        XCTAssertTrue(downloadQueue.isDownloading)
        XCTAssertNil(streamManager.handler(song: song), "the promoted handler leaves the stream lane's stack")
        XCTAssertTrue(handler.delegate === downloadQueue, "the promotion atomically flips the handler's delegate to the engine")
        XCTAssertTrue(downloadQueue.currentStreamHandler === handler)
        XCTAssertTrue(waitUntil { handler.isDownloading }, "the promoted handler is resumed")
    }

    // MARK: stop (BUG-05)

    func testStopCancelsActiveDownload_BUG05() {
        MockSubsonicServer.stubStalling(.stream, data: Data(repeating: 1, count: 100_000))
        _ = makeQueuedSong(id: "1")

        downloadQueue.start()
        XCTAssertTrue(downloadQueue.isDownloading)
        let handler = downloadQueue.currentStreamHandler

        downloadQueue.stop()

        XCTAssertFalse(downloadQueue.isDownloading, "stop() must cancel an in-flight download")
        XCTAssertNil(downloadQueue.currentStreamHandler)
        XCTAssertEqual(handler?.isDownloading, false, "the active stream handler must be cancelled")
    }

    func testStopWhenIdleIsANoOp() {
        // With nothing downloading there is nothing to stop, so no notification fires
        // (matches the old ISMSCacheQueueManager.stopDownloadQueue semantics)
        let stoppedExpectation = expectation(forNotification: Notifications.downloadQueueStopped, object: nil, handler: nil)
        stoppedExpectation.isInverted = true
        downloadQueue.stop()
        wait(for: [stoppedExpectation], timeout: 1)
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
        XCTAssertEqual(handler?.isDownloading, false, "the in-flight handler is cancelled by stop()")
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
