//
//  StreamManagerTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// COV-08: StreamManager queue management, fillStreamQueue gating, handler-stack
// persistence, and the connectionFinished/Failed delegate state machine.
final class StreamManagerTests: StoreTestCase {
    private var streamManager: StreamManager!
    private var playQueue: PlayQueue!
    private var settings: SavedSettings!
    private var player: FakePlayer!
    private var downloadQueue: FakeDownloadQueue!
    private var network: FakeNetworkStatus!

    override func setUpWithError() throws {
        try super.setUpWithError()
        MockSubsonicServer.install()
        XCTAssertTrue(store.add(server: TestData.server(id: 1, urlString: "https://mock.example.com")))

        player = FakePlayer()
        downloadQueue = FakeDownloadQueue()
        network = FakeNetworkStatus()
        let fakePlayer = player!
        let fakeDownloadQueue = downloadQueue!
        TestContainer.register { fakePlayer as PlayerControlling }
        TestContainer.register { fakeDownloadQueue as DownloadQueueing }

        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        settings = freshSettings

        let freshPlayQueue = makeTestPlayQueue()
        TestContainer.register { freshPlayQueue }
        playQueue = freshPlayQueue

        // The handler stack now persists to SavedSettings.defaults, which the sandbox
        // isolates per test, so no manual key scrubbing is needed
        streamManager = makeStreamManager()
    }

    // Builds a StreamManager wired to this test's fakes (the composition root's job
    // in production)
    private func makeStreamManager() -> StreamManager {
        let manager = StreamManager(store: store,
                                    settings: settings,
                                    player: player,
                                    downloadsManager: DownloadsManager(settings: settings, store: store),
                                    networkStatus: network,
                                    metadataDownloader: FakeSongMetadataDownloader())
        manager.attach(downloadQueue: downloadQueue)
        manager.attach(playQueue: playQueue)
        return manager
    }

    override func tearDownWithError() throws {
        streamManager?.cancelAllStreams()
        streamManager = nil
        playQueue = nil
        settings = nil
        player = nil
        downloadQueue = nil
        MockSubsonicServer.uninstall()
        try super.tearDownWithError()
    }

    private func makeSong(id: String, isVideo: Bool = false) -> Song {
        let song = TestData.song(serverId: 1, id: id, title: "Song \(id)", path: "Artist/Album/\(id).mp3", isVideo: isVideo)
        _ = store.add(song: song)
        return song
    }

    private func seedPlayQueue(_ songs: [Song]) {
        for song in songs {
            XCTAssertTrue(store.add(song: song, localPlaylistId: LocalPlaylist.Default.playQueueId))
        }
    }

    // Spins the main run loop until the condition is true or the timeout elapses
    @discardableResult
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return condition()
    }

    // MARK: queueStream

    func testQueueStreamAddsHandlerWithoutStarting() {
        let song = makeSong(id: "1")

        streamManager.queueStream(song: song, tempCache: false, startDownload: false)

        XCTAssertTrue(streamManager.isInQueue(song: song))
        XCTAssertNotNil(streamManager.handler(song: song))
        XCTAssertTrue(streamManager.isFirstInQueue(song: song))
        XCTAssertFalse(streamManager.isDownloading(song: song))
        XCTAssertEqual(MockSubsonicServer.receivedRequests.count, 0)
    }

    func testQueueStreamIgnoresDuplicatesAndInvalidIndexes() {
        let song = makeSong(id: "1")
        streamManager.queueStream(song: song, tempCache: false, startDownload: false)
        streamManager.queueStream(song: song, tempCache: false, startDownload: false)
        XCTAssertNotNil(streamManager.handler(song: song))

        let other = makeSong(id: "2")
        streamManager.queueStream(song: other, byteOffset: 0, secondsOffset: 0, index: 99, tempCache: false, startDownload: false)
        XCTAssertFalse(streamManager.isInQueue(song: other), "out-of-bounds insert index must be rejected")
    }

    func testQueueStreamStartsDownloadWhenFirstInQueue() {
        MockSubsonicServer.stubStalling(.stream, data: Data(repeating: 1, count: 10_000))
        let song = makeSong(id: "1")

        streamManager.queueStream(song: song, tempCache: false, startDownload: true)

        XCTAssertTrue(waitUntil { self.streamManager.isDownloading(song: song) }, "the first queued handler starts downloading")
    }

    // MARK: fillStreamQueue

    func testFillStreamQueueQueuesCurrentAndNextSong() {
        settings.isSongCachingEnabled = true
        settings.isNextSongCacheEnabled = true
        let songs = [makeSong(id: "1"), makeSong(id: "2"), makeSong(id: "3")]
        seedPlayQueue(songs)
        playQueue.currentIndex = 0

        streamManager.fillStreamQueue(startDownload: false)

        XCTAssertTrue(streamManager.isInQueue(song: songs[0]))
        XCTAssertTrue(streamManager.isInQueue(song: songs[1]))
        XCTAssertFalse(streamManager.isInQueue(song: songs[2]), "only current + next are prefetched")
    }

    func testFillStreamQueueOnlyQueuesCurrentSongWhenNextSongCacheDisabled() {
        settings.isSongCachingEnabled = true
        settings.isNextSongCacheEnabled = false
        let songs = [makeSong(id: "1"), makeSong(id: "2")]
        seedPlayQueue(songs)
        playQueue.currentIndex = 0

        streamManager.fillStreamQueue(startDownload: false)

        XCTAssertTrue(streamManager.isInQueue(song: songs[0]))
        XCTAssertFalse(streamManager.isInQueue(song: songs[1]))
    }

    func testFillStreamQueueSkipsVideosCachedAndAlreadyQueuedSongs() {
        settings.isSongCachingEnabled = true
        settings.isNextSongCacheEnabled = true

        let video = makeSong(id: "1", isVideo: true)
        let cached = makeSong(id: "2")
        _ = store.add(downloadedSong: DownloadedSong(song: cached))
        _ = store.update(downloadFinished: true, song: cached)
        seedPlayQueue([video, cached])
        playQueue.currentIndex = 0

        streamManager.fillStreamQueue(startDownload: false)

        XCTAssertFalse(streamManager.isInQueue(song: video), "videos are never prefetched")
        XCTAssertFalse(streamManager.isInQueue(song: cached), "fully cached songs are never prefetched")
    }

    func testFillStreamQueueSkipsDownloadQueueCurrentSong() {
        settings.isSongCachingEnabled = true
        settings.isNextSongCacheEnabled = true
        let songs = [makeSong(id: "1"), makeSong(id: "2")]
        seedPlayQueue(songs)
        playQueue.currentIndex = 0
        downloadQueue.currentQueuedSong = songs[0]

        streamManager.fillStreamQueue(startDownload: false)

        XCTAssertFalse(streamManager.isInQueue(song: songs[0]), "the download queue's active song must not be double-downloaded")
        XCTAssertTrue(streamManager.isInQueue(song: songs[1]))
    }

    func testFillStreamQueueNoOpInJukeboxAndOfflineModes() {
        settings.isSongCachingEnabled = true
        settings.isNextSongCacheEnabled = true
        let song = makeSong(id: "1")
        seedPlayQueue([song])
        playQueue.currentIndex = 0

        settings.isJukeboxEnabled = true
        // Seed the jukebox play queue too: in jukebox mode currentPlaylistId points
        // there, so an empty jukebox queue would mask a missing guard (it did —
        // the Phase 8.8 guard removal passed this test but broke JukeboxUITests)
        XCTAssertTrue(store.add(song: song, localPlaylistId: LocalPlaylist.Default.jukeboxPlayQueueId))
        streamManager.fillStreamQueue(startDownload: false)
        XCTAssertFalse(streamManager.isInQueue(song: song))

        settings.isJukeboxEnabled = false
        settings.isOfflineMode = true
        streamManager.fillStreamQueue(startDownload: false)
        XCTAssertFalse(streamManager.isInQueue(song: song))
    }

    func testFillStreamQueueUsesTempCacheWhenSongCachingDisabled() throws {
        settings.isSongCachingEnabled = false
        let song = makeSong(id: "1")
        seedPlayQueue([song])
        playQueue.currentIndex = 0

        streamManager.fillStreamQueue(startDownload: false)

        let handler = try XCTUnwrap(streamManager.handler(song: song))
        XCTAssertTrue(handler.isTempCache, "with song caching disabled, prefetch uses the temp cache")
    }

    // MARK: removeAllStreams

    func testRemoveAllStreamsExceptKeepsOnlyExcepted() {
        let songA = makeSong(id: "1")
        let songB = makeSong(id: "2")
        streamManager.queueStream(song: songA, tempCache: false, startDownload: false)
        streamManager.queueStream(song: songB, tempCache: false, startDownload: false)

        streamManager.removeAllStreams(except: songB)

        XCTAssertFalse(streamManager.isInQueue(song: songA))
        XCTAssertTrue(streamManager.isInQueue(song: songB))
    }

    func testRemoveStreamByIndex() {
        let songA = makeSong(id: "1")
        let songB = makeSong(id: "2")
        streamManager.queueStream(song: songA, tempCache: false, startDownload: false)
        streamManager.queueStream(song: songB, tempCache: false, startDownload: false)

        streamManager.removeStream(index: 0)

        XCTAssertFalse(streamManager.isInQueue(song: songA))
        XCTAssertTrue(streamManager.isInQueue(song: songB))
        // Out-of-bounds indexes are ignored
        streamManager.removeStream(index: 5)
        XCTAssertTrue(streamManager.isInQueue(song: songB))
    }

    // MARK: Handler stack persistence

    func testSaveAndLoadHandlerStackRoundTrip() throws {
        let songA = makeSong(id: "1")
        let songB = makeSong(id: "2")
        streamManager.queueStream(song: songA, byteOffset: 100, secondsOffset: 5.5, index: 0, tempCache: false, startDownload: false)
        streamManager.queueStream(song: songB, tempCache: true, startDownload: false)
        streamManager.saveHandlerStack()

        // A fresh manager (fresh launch) loads the same stack from UserDefaults
        let newManager = makeStreamManager()
        newManager.loadHandlerStack()

        let handlerA = try XCTUnwrap(newManager.handler(song: songA))
        XCTAssertEqual(handlerA.byteOffset, 100)
        XCTAssertEqual(handlerA.secondsOffset, 5.5, accuracy: 0.001)
        XCTAssertFalse(handlerA.isTempCache)
        let handlerB = try XCTUnwrap(newManager.handler(song: songB))
        XCTAssertTrue(handlerB.isTempCache)
        XCTAssertTrue(newManager.isFirstInQueue(song: songA), "stack order must survive the round trip")
    }

    // MARK: streamHandlerConnectionFinished

    func testConnectionFinishedMarksSongDownloaded() {
        MockSubsonicServer.stub(.stream, data: Data(repeating: 1, count: 5000), contentType: "audio/mpeg")
        let song = makeSong(id: "1")
        downloadQueue.queuedSongs = [song]

        let downloadedExpectation = expectation(forNotification: Notifications.streamHandlerSongDownloaded, object: nil, handler: nil)
        streamManager.queueStream(song: song, tempCache: false, startDownload: true)
        wait(for: [downloadedExpectation], timeout: 10)

        XCTAssertTrue(store.isDownloadFinished(song: song), "completed downloads are marked finished")
        XCTAssertFalse(streamManager.isInQueue(song: song), "the finished handler leaves the stack")
        XCTAssertEqual(streamManager.lastCachedSong, song)
    }

    func testConnectionFinishedZeroByteBodyDeletesFileAndDoesNotMarkDownloaded() {
        MockSubsonicServer.stub(.stream, data: Data(), contentType: "audio/mpeg")
        let song = makeSong(id: "1")

        streamManager.queueStream(song: song, tempCache: false, startDownload: true)

        XCTAssertTrue(waitUntil { !self.streamManager.isDownloading(song: song) })
        // Give the main-thread delegate callback time to run
        waitUntil { !FileManager.default.fileExists(atPath: song.localPath) }

        XCTAssertFalse(store.isDownloadFinished(song: song), "an empty response must not be marked as downloaded")
        XCTAssertFalse(FileManager.default.fileExists(atPath: song.localPath), "the empty file must be deleted")
    }

    func testConnectionFinishedTrialExpiredBodyDeletesFileAndDoesNotMarkDownloaded() throws {
        // A tiny XML error body (e.g. Subsonic trial expired) instead of audio bytes
        let errorXML = #"<subsonic-response status="failed" version="1.15.0"><error code="60" message="Trial period is over."/></subsonic-response>"#
        MockSubsonicServer.stub(.stream, data: Data(errorXML.utf8), contentType: "text/xml")
        let song = makeSong(id: "1")

        streamManager.queueStream(song: song, tempCache: false, startDownload: true)

        XCTAssertTrue(waitUntil { !self.streamManager.isDownloading(song: song) })
        waitUntil { !FileManager.default.fileExists(atPath: song.localPath) }

        XCTAssertFalse(store.isDownloadFinished(song: song), "a trial-expired body must not be marked as downloaded")
        XCTAssertFalse(FileManager.default.fileExists(atPath: song.localPath), "the error-body file must be deleted")
    }

    // MARK: streamHandlerConnectionFailed retry cap

    func testConnectionFailedRetriesUntilCapThenRemoves() {
        let song = makeSong(id: "1")
        streamManager.queueStream(song: song, tempCache: false, startDownload: false)
        let handler = streamManager.handler(song: song)!

        // First maxNumberOfReconnects failures schedule retries
        for attempt in 1...5 {
            streamManager.streamHandlerConnectionFailed(handler: handler, error: APIError.serverUnreachable)
            XCTAssertEqual(handler.numberOfReconnects, attempt)
            XCTAssertTrue(streamManager.isInQueue(song: song), "handler stays queued while retrying (attempt \(attempt))")
        }

        // The next failure exceeds the cap: the handler is removed and the failure posted
        let failedExpectation = expectation(forNotification: Notifications.streamHandlerSongFailed, object: nil, handler: nil)
        streamManager.streamHandlerConnectionFailed(handler: handler, error: APIError.serverUnreachable)
        wait(for: [failedExpectation], timeout: 5)
        XCTAssertFalse(streamManager.isInQueue(song: song), "the handler is removed after exhausting retries")
    }

    // MARK: BUG-25 stream-queue maintenance

    func testCurrentPlaylistIndexChangedRemovesStaleHandlersAndRefills_BUG25() {
        MockSubsonicServer.stubStalling(.stream, data: Data(repeating: 1, count: 10_000))
        settings.isSongCachingEnabled = true
        settings.isNextSongCacheEnabled = true
        let songs = (1...5).map { makeSong(id: "\($0)") }
        seedPlayQueue(songs)
        playQueue.currentIndex = 0
        streamManager.setup()

        streamManager.fillStreamQueue(startDownload: false)
        XCTAssertTrue(streamManager.isInQueue(song: songs[0]))
        XCTAssertTrue(streamManager.isInQueue(song: songs[1]))

        // Jump several positions: the handlers for songs 1/2 are now stale and must be
        // replaced by the new current + next songs (removing only prevSong missed them)
        playQueue.currentIndex = 3

        XCTAssertFalse(streamManager.isInQueue(song: songs[0]), "stale handler for the old current song must be removed")
        XCTAssertFalse(streamManager.isInQueue(song: songs[1]), "stale handler for the old next song must be removed")
        XCTAssertTrue(streamManager.isInQueue(song: songs[3]), "the new current song is prefetched")
        XCTAssertTrue(streamManager.isInQueue(song: songs[4]), "the new next song is prefetched")
    }

    func testRemoveStreamDeletesPartialDownloadRecord_BUG25() {
        // The old guard was self-contradictory, so the delete branch never ran and
        // partial download rows accumulated
        let song = makeSong(id: "1")
        _ = store.add(downloadedSong: DownloadedSong(song: song))
        streamManager.queueStream(song: song, tempCache: false, startDownload: false)

        streamManager.removeStream(song: song)

        XCTAssertNil(store.downloadedSong(serverId: 1, songId: "1"),
                     "removing a partial stream must clean up its download record")
    }

    func testRemoveStreamKeepsDownloadRecordWhenDownloadQueueOwnsTheSong_BUG25() {
        let song = makeSong(id: "1")
        _ = store.add(downloadedSong: DownloadedSong(song: song))
        streamManager.queueStream(song: song, tempCache: false, startDownload: false)

        // The download queue is actively downloading this same song, so the record
        // must survive the stream handler's removal
        downloadQueue.currentQueuedSong = song
        downloadQueue.isDownloading = true
        streamManager.removeStream(song: song)

        XCTAssertNotNil(store.downloadedSong(serverId: 1, songId: "1"),
                        "the download queue's active song must keep its record")
    }

    func testRetrySchedulingIsPerHandler_BUG25() {
        // Canceling one handler's pending retry must not cancel another's: the old code
        // kept a single shared work item
        MockSubsonicServer.stubStalling(.stream, data: Data(repeating: 1, count: 10_000))
        let songA = makeSong(id: "A")
        let songB = makeSong(id: "B")
        streamManager.queueStream(song: songA, tempCache: false, startDownload: false)
        streamManager.queueStream(song: songB, tempCache: false, startDownload: false)
        let handlerA = streamManager.handler(song: songA)!

        // Handler A fails and schedules its 1.5s retry; canceling B must not touch it
        streamManager.streamHandlerConnectionFailed(handler: handlerA, error: APIError.serverUnreachable)
        streamManager.cancelStream(song: songB)

        XCTAssertTrue(waitUntil(timeout: 5) { self.streamManager.isDownloading(song: songA) },
                      "handler A's scheduled retry must survive canceling handler B")
    }

    // MARK: Handler stealing

    func testRemoveFromStackRemovesHandler() {
        let song = makeSong(id: "1")
        streamManager.queueStream(song: song, tempCache: false, startDownload: false)
        let handler = streamManager.handler(song: song)!

        streamManager.removeFromStack(handler: handler)

        XCTAssertFalse(streamManager.isInQueue(song: song), "a stolen handler no longer belongs to the stream manager")
    }
}
