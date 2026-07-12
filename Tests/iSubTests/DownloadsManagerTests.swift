//
//  DownloadsManagerTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/10/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// BUG-16: cache eviction ordering (both caching types and auto-delete types) and
// loop termination when nothing more can be deleted.
final class DownloadsManagerTests: StoreTestCase {
    private var settings: SavedSettings!
    private var downloadQueue: FakeDownloadQueue!
    private var manager: DownloadsManager!

    override func setUpWithError() throws {
        try super.setUpWithError()

        XCTAssertTrue(store.add(server: TestData.server(id: 1)))

        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        settings = freshSettings

        downloadQueue = FakeDownloadQueue()
        let fakeDownloadQueue = downloadQueue!
        TestContainer.register { fakeDownloadQueue as DownloadQueueing }

        manager = DownloadsManager(settings: freshSettings, store: store)
    }

    override func tearDownWithError() throws {
        manager?.stopCacheCheckTimer()
        manager = nil
        downloadQueue = nil
        settings = nil
        try super.tearDownWithError()
    }

    // Adds a finished downloaded song with a real file of the given size at its local path
    @discardableResult
    private func addDownload(songId: String, sizeInBytes: Int, downloadedDate: Date? = nil, playedDate: Date? = nil) -> Song {
        let song = TestData.song(serverId: 1, id: songId, title: "Song \(songId)", path: "Artist/Album/\(songId).mp3")
        XCTAssertTrue(store.add(song: song))

        var downloadedSong = DownloadedSong(song: song)
        downloadedSong.downloadedDate = downloadedDate
        downloadedSong.playedDate = playedDate
        XCTAssertTrue(store.add(downloadedSong: downloadedSong))
        XCTAssertTrue(store.update(downloadFinished: true, serverId: 1, songId: songId))

        let fileURL = URL(fileURLWithPath: song.localPath)
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        XCTAssertNoThrow(try Data(repeating: 1, count: sizeInBytes).write(to: fileURL))
        return song
    }

    private func downloadedSongIds() -> [String] {
        store.downloadedSongs(serverId: 1).map(\.songId)
    }

    func testMaxSizeEvictionRemovesOldestDownloadedFirstUntilUnderLimit() {
        settings.cachingType = CachingType.maxSize.rawValue
        settings.autoDeleteCacheType = 1 // by downloaded date
        let oldest = addDownload(songId: "1", sizeInBytes: 10_000, downloadedDate: Date(timeIntervalSince1970: 1000))
        let middle = addDownload(songId: "2", sizeInBytes: 10_000, downloadedDate: Date(timeIntervalSince1970: 2000))
        let newest = addDownload(songId: "3", sizeInBytes: 10_000, downloadedDate: Date(timeIntervalSince1970: 3000))

        manager.findCacheSize()
        XCTAssertGreaterThanOrEqual(manager.cacheSize, 30_000)

        // Allow one file to remain: the two oldest must be evicted, oldest first
        settings.maxCacheSize = 15_000
        manager.removeOldestCachedSongs()

        XCTAssertEqual(downloadedSongIds(), ["3"], "only the newest download survives")
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldest.localPath))
        XCTAssertFalse(FileManager.default.fileExists(atPath: middle.localPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newest.localPath))
        // The restart hops to the main queue (eviction runs on the background
        // cache-check queue in production, and the engine's state is main-confined)
        let deadline = Date(timeIntervalSinceNow: 2)
        while downloadQueue.startCount == 0 && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        XCTAssertEqual(downloadQueue.startCount, 1, "the download queue is restarted after eviction frees space")
    }

    func testMaxSizeEvictionRemovesOldestPlayedFirst() {
        settings.cachingType = CachingType.maxSize.rawValue
        settings.autoDeleteCacheType = 0 // by played date
        let playedLongAgo = addDownload(songId: "1", sizeInBytes: 10_000, playedDate: Date(timeIntervalSince1970: 1000))
        let playedRecently = addDownload(songId: "2", sizeInBytes: 10_000, playedDate: Date(timeIntervalSince1970: 9000))

        manager.findCacheSize()
        settings.maxCacheSize = 15_000
        manager.removeOldestCachedSongs()

        XCTAssertEqual(downloadedSongIds(), ["2"], "the least recently played download is evicted first")
        XCTAssertFalse(FileManager.default.fileExists(atPath: playedLongAgo.localPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: playedRecently.localPath))
    }

    func testMaxSizeEvictionTerminatesWhenNoCandidatesRemain_BUG16() {
        // Even after deleting everything the cache size target can't be met (the size
        // bookkeeping only shrinks by deleted file sizes); the loop must bail instead
        // of spinning forever once no more songs can be deleted
        settings.cachingType = CachingType.maxSize.rawValue
        settings.autoDeleteCacheType = 1
        addDownload(songId: "1", sizeInBytes: 10_000, downloadedDate: Date(timeIntervalSince1970: 1000))

        manager.findCacheSize()
        // Simulate other data in the cache dir: target far below what deleting can reach
        settings.maxCacheSize = -100_000
        manager.removeOldestCachedSongs()

        XCTAssertEqual(downloadedSongIds(), [], "everything deletable is deleted")
        // Reaching this line at all proves the loop terminated
    }

    // MARK: Backup exclusion (STUB-06)

    private func isExcludedFromBackup(_ path: String) throws -> Bool {
        try URL(fileURLWithPath: path).resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup ?? false
    }

    private func waitFor(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return condition()
    }

    func testApplyBackupExclusionMarksEveryFileIndividually() throws {
        // Two songs in different subdirectories — the flag must be set per file
        let songA = addDownload(songId: "1", sizeInBytes: 10)
        let songB = TestData.song(serverId: 1, id: "2", title: "Song 2", path: "Other/Album/2.mp3")
        let fileB = URL(fileURLWithPath: songB.localPath)
        try FileManager.default.createDirectory(at: fileB.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 10).write(to: fileB)

        manager.applyBackupExclusionToAllDownloads(isExcludedFromBackup: true)
        XCTAssertTrue(try isExcludedFromBackup(songA.localPath))
        XCTAssertTrue(try isExcludedFromBackup(songB.localPath))

        manager.applyBackupExclusionToAllDownloads(isExcludedFromBackup: false)
        XCTAssertFalse(try isExcludedFromBackup(songA.localPath))
        XCTAssertFalse(try isExcludedFromBackup(songB.localPath))
    }

    func testBackupCacheSettingToggleUpdatesExistingFiles() throws {
        // The SavedSettings didSet posts backupCacheSettingChanged, which the manager
        // (observing since init) applies to the existing downloads
        let song = addDownload(songId: "1", sizeInBytes: 10)

        settings.isBackupCacheEnabled = false
        XCTAssertTrue(waitFor { (try? isExcludedFromBackup(song.localPath)) == true },
                      "disabling backup must exclude existing downloads from backup")

        settings.isBackupCacheEnabled = true
        XCTAssertTrue(waitFor { (try? isExcludedFromBackup(song.localPath)) == false },
                      "enabling backup must clear the exclusion on existing downloads")
    }

    func testMinSpaceEvictionTerminatesWhenNoCandidatesRemain_BUG16() {
        // Free space can never exceed Int.max, so without the nil-candidate guard this
        // spins forever once the (single) song is gone
        settings.cachingType = CachingType.minSpace.rawValue
        settings.autoDeleteCacheType = 1
        let song = addDownload(songId: "1", sizeInBytes: 10_000, downloadedDate: Date(timeIntervalSince1970: 1000))

        settings.minFreeSpace = Int.max
        manager.removeOldestCachedSongs()

        XCTAssertEqual(downloadedSongIds(), [], "everything deletable is deleted")
        XCTAssertFalse(FileManager.default.fileExists(atPath: song.localPath))
        // Reaching this line at all proves the loop terminated
    }
}
