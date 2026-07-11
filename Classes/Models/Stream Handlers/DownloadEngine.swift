//
//  DownloadEngine.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// The single owner of the download subsystem (Phase 8.10a): constructs the stream
// manager (temp/prefetch lane) and download queue (permanent lane), wires their
// internal steal back-edge in one place, and exposes one setup(). External code
// keeps talking to the StreamManaging/DownloadQueueing protocol seams, which the
// composition root points at this engine's instances. Phase 8.10b merges the two
// lanes' logic into this type so the handler steal becomes an internal atomic
// transfer.
final class DownloadEngine {
    let streamManager: StreamManager
    let downloadQueue: DownloadQueue

    init(store: Store, settings: SavedSettings, downloadsManager: DownloadsManager,
         player: PlayerControlling, networkStatus: NetworkStatus) {
        streamManager = StreamManager(store: store,
                                      settings: settings,
                                      player: player,
                                      downloadsManager: downloadsManager,
                                      networkStatus: networkStatus,
                                      metadataDownloader: SongMetadataDownloader())
        downloadQueue = DownloadQueue(store: store,
                                      settings: settings,
                                      downloadsManager: downloadsManager,
                                      player: player,
                                      networkStatus: networkStatus,
                                      streamManager: streamManager,
                                      metadataDownloader: SongMetadataDownloader())
        // The steal back-edge: the stream manager consults the download queue's
        // read-only status before deleting partial downloads or filling its queue
        streamManager.attach(downloadQueue: downloadQueue)
    }

    func attach(playQueue: PlayQueue) {
        streamManager.attach(playQueue: playQueue)
    }

    // Restores the persisted handler stack and resumes interrupted downloads
    func setup() {
        streamManager.setup()
    }
}
