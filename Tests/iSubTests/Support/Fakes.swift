//
//  Fakes.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import Resolver
@testable import iSub_Beta

// Mirrors the composition root for tests: builds a PlayQueue wired to whatever is
// currently registered in the container. Register any fakes (settings, store)
// BEFORE calling this — resolution happens here, not lazily on first use.
func makeTestPlayQueue() -> PlayQueue {
    PlayQueue(store: Resolver.resolve(),
              settings: Resolver.resolve())
}

// Same pattern for the playback facade: builds a PlaybackCoordinator over the given
// queue (or a fresh one) with whatever is currently registered in the container
func makeTestPlaybackCoordinator(queue: PlayQueue? = nil) -> PlaybackCoordinator {
    PlaybackCoordinator(queue: queue ?? makeTestPlayQueue(),
                        settings: Resolver.resolve(),
                        store: Resolver.resolve(),
                        player: Resolver.resolve(),
                        jukebox: Resolver.resolve(),
                        streamManager: Resolver.resolve(),
                        downloadQueue: Resolver.resolve())
}

// Recording fakes for the protocol seams registered in DependencyInjection.swift.
// Register them over the app's singletons with TestContainer, e.g.:
//     let player = FakePlayer()
//     TestContainer.register { player as PlayerControlling }

final class FakeNetworkStatus: NetworkStatus {
    var isWifi = true
    var isNetworkReachable = true
}

final class FakePlayer: PlayerControlling {
    var isPlaying = false
    var isStarted = false
    var progress = 0.0
    var kiloBitrate = 0
    var currentByteOffset = 0
    var currentStream: BassStream?
    var startByteOffset = 0
    var startSecondsOffset = 0.0

    private(set) var startedSongs = [(song: Song, index: Int, offsetInBytes: Int, offsetInSeconds: Double)]()
    private(set) var pauseCount = 0
    private(set) var playPauseCount = 0
    private(set) var stopCount = 0
    private(set) var seeks = [(seconds: Double, fadeVolume: Bool)]()
    var seekSucceeds = true

    func startNewSong(_ song: Song, index: Int, offsetInBytes: Int, offsetInSeconds: Double) {
        startedSongs.append((song, index, offsetInBytes, offsetInSeconds))
        isPlaying = true
        isStarted = true
    }

    func pause() {
        pauseCount += 1
        isPlaying = false
    }

    func playPause() {
        playPauseCount += 1
        isPlaying.toggle()
    }

    func stop() {
        stopCount += 1
        isPlaying = false
        isStarted = false
    }

    @discardableResult func seekToPosition(seconds: Double, fadeVolume: Bool) -> Bool {
        seeks.append((seconds, fadeVolume))
        return seekSucceeds
    }

    func streamReadyToStartPlayback(handler: StreamHandler) {}

    private(set) var preparedNextSongs = [Song]()
    func prepareNext(song: Song) { preparedNextSongs.append(song) }
}

final class FakeStreamManager: StreamManaging {
    var isDownloading = false
    var firstHandlerInQueue: StreamHandler?
    var lastTempCachedSong: Song?

    private(set) var setupCount = 0
    private(set) var queuedStreams = [(song: Song, byteOffset: Int, secondsOffset: Double, index: Int, tempCache: Bool, startDownload: Bool)]()
    private(set) var fillStreamQueueCalls = [Bool]()
    private(set) var removeAllStreamsCount = 0
    private(set) var removeAllStreamsExceptSongs = [Song]()
    private(set) var removedStreamIndexes = [Int]()
    private(set) var resumeQueueCount = 0

    var downloadingSongs = Set<Song>()
    var firstInQueueSongs = Set<Song>()
    var handlersBySong = [Song: StreamHandler]()

    func setup() { setupCount += 1 }
    func handler(song: Song) -> StreamHandler? { handlersBySong[song] }
    func isFirstInQueue(song: Song) -> Bool { firstInQueueSongs.contains(song) }
    func isDownloading(song: Song) -> Bool { downloadingSongs.contains(song) }
    func removeAllStreams() { removeAllStreamsCount += 1 }
    func removeAllStreams(except song: Song) { removeAllStreamsExceptSongs.append(song) }
    func removeStream(index: Int) { removedStreamIndexes.append(index) }
    func resumeQueue() { resumeQueueCount += 1 }

    func queueStream(song: Song, byteOffset: Int, secondsOffset: Double, index: Int, tempCache: Bool, startDownload: Bool) {
        queuedStreams.append((song, byteOffset, secondsOffset, index, tempCache, startDownload))
    }

    func queueStream(song: Song, tempCache: Bool, startDownload: Bool) {
        queueStream(song: song, byteOffset: 0, secondsOffset: 0.0, index: queuedStreams.count, tempCache: tempCache, startDownload: startDownload)
    }

    func fillStreamQueue(startDownload: Bool) { fillStreamQueueCalls.append(startDownload) }
    func streamHandlerStartPlayback(handler: StreamHandler) {}
}

final class FakeDownloadQueue: DownloadQueueing {
    var isDownloading = false
    var currentQueuedSong: Song?
    var currentStreamHandler: StreamHandler?
    var queuedSongs = Set<Song>()

    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var removeCurrentSongCount = 0
    private(set) var clearCount = 0

    func isInQueue(song: Song) -> Bool { queuedSongs.contains(song) }

    func start() {
        startCount += 1
        isDownloading = true
    }

    func stop() {
        stopCount += 1
        isDownloading = false
    }

    @discardableResult func removeCurrentSong() -> Bool {
        removeCurrentSongCount += 1
        currentQueuedSong = nil
        return true
    }

    @discardableResult func clear() -> Bool {
        clearCount += 1
        queuedSongs.removeAll()
        currentQueuedSong = nil
        return true
    }
}

// Registered by default in SandboxedTestCase so no test spawns the real fire-and-forget
// metadata prefetch: its background Task outlives the test that triggered it and races
// the next test's DI re-registration (crashes the test host in ResolverScopeCache)
final class FakeSongMetadataDownloader: SongMetadataDownloading {
    private(set) var downloadedSongs = [Song]()

    func downloadMetadata(song: Song) {
        downloadedSongs.append(song)
    }
}

