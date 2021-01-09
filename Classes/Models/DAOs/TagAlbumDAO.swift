//
//  TagAlbumDAO.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

@objc final class TagAlbumDAO: NSObject {
    @Injected private var store: Store
    
    var serverId = Settings.shared().currentServerId
    private let tagAlbumId: Int
    private var loader: TagAlbumLoader?
    private var songIds = [Int]()

    @objc weak var delegate: SUSLoaderDelegate?

    @objc var hasLoaded: Bool { songIds.count > 0 }
    @objc var songCount: Int { songIds.count }

    @objc init(tagAlbumId: Int, delegate: SUSLoaderDelegate?) {
        self.tagAlbumId = tagAlbumId
        self.delegate = delegate
        super.init()
        loadFromCache()
    }

    deinit {
        loader?.cancelLoad()
        loader?.callback = nil
    }

    @objc func song(indexPath: IndexPath) -> Song? {
        guard indexPath.row < songIds.count else { return nil }
        return store.song(serverId: serverId, id: songIds[indexPath.row])
    }
    
    @objc func playSong(row: Int) -> Song? {
        fatalError("implement this")
//        // Clear the current playlist
//        if Settings.shared().isJukeboxEnabled {
//            DatabaseOld.shared().resetJukeboxPlaylist()
//            Jukebox.shared().clearRemotePlaylist()
//        } else {
//            DatabaseOld.shared().resetCurrentPlaylistDb()
//        }
//
//        // Add the songs to the playlist
//        DatabaseOld.shared().serverDbQueue?.inDatabase { db in
//            let query = """
//                INSERT INTO currentPlaylist
//                SELECT songId, itemOrder
//                FROM tagSong
//                WHERE albumId = ?
//                ORDER BY itemOrder ASC
//            """
//            if !db.executeUpdate(query, tagAlbumId) {
//                DDLogError("[TagAlbumDAO] Error inserting album \(tagAlbumId)'s songs into current playlist \(db.lastErrorCode()): \(db.lastErrorMessage())");
//            }
//        }
//
//        // Set player defaults
//        PlayQueue.shared().isShuffle = false
//
//        NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
//
//        // Start the song
//        return Music.shared().playSong(atPosition: row)
    }
    
    private func loadFromCache() {
        songIds = store.songIds(serverId: serverId, tagAlbumId: tagAlbumId)
    }
}

@objc extension TagAlbumDAO: SUSLoaderManager {
    func startLoad() {
        loader = TagAlbumLoader(tagAlbumId: tagAlbumId) { [unowned self] success, error in
            songIds = self.loader?.songIds ?? []
            self.loader = nil

            if success {
                delegate?.loadingFinished(nil)
            } else {
                delegate?.loadingFailed(nil, withError: error)
            }
        }
        loader?.startLoad()
    }

    func cancelLoad() {
        loader?.cancelLoad()
        loader = nil
    }
}
