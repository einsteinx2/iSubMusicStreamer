//
//  TagAlbumDAO.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

@objc final class TagAlbumDAO: NSObject {
    private let albumId: String
    private var loader: TagAlbumLoader?
    private var songs = [Song]()

    @objc weak var delegate: SUSLoaderDelegate?

    @objc var hasLoaded: Bool { songs.count > 0 }
    @objc var songCount: Int { songs.count }

    @objc init(albumId: String, delegate: SUSLoaderDelegate?) {
        self.albumId = albumId
        self.delegate = delegate
        super.init()
        loadSongs()
    }

    deinit {
        loader?.cancelLoad()
    }

    @objc func song(row: Int) -> Song {
        return songs[row]
    }
    
    @objc func playSong(row: Int) -> Song? {
        // Clear the current playlist
        if Settings.shared().isJukeboxEnabled {
            Database.shared().resetJukeboxPlaylist()
            Jukebox.shared().clearRemotePlaylist()
        } else {
            Database.shared().resetCurrentPlaylistDb()
        }
        
        // Add the songs to the playlist
        Database.shared().serverDbQueue?.inDatabase { db in
            let query = """
                INSERT INTO currentPlaylist
                SELECT songId, itemOrder
                FROM tagSong
                WHERE albumId = ?
                ORDER BY itemOrder ASC
            """
            if !db.executeUpdate(query, albumId) {
                DDLogError("[TagAlbumDAO] Error inserting album \(albumId)'s songs into current playlist \(db.lastErrorCode()): \(db.lastErrorMessage())");
            }
        }
        
        // Set player defaults
        PlayQueue.shared().isShuffle = false
        
        NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
        
        // Start the song
        return Music.shared().playSong(atPosition: row)
    }

    private func loadSongs() {
        songs.removeAll()
        Database.shared().serverDbQueue?.inDatabase { db in
            let query = """
                SELECT song.*
                FROM tagSong
                JOIN song ON tagSong.songId = song.songId
                WHERE tagSong.albumId = ?
                ORDER BY tagSong.itemOrder ASC
            """
            if let result = db.executeQuery(query, albumId) {
                while result.next() {
                    songs.append(Song(result: result))
                }
            } else {
                DDLogError("[TagAlbumDAO] Failed to read songs for albumId \(albumId)")
            }
        }
    }
}

@objc extension TagAlbumDAO: SUSLoaderManager {
    func startLoad() {
        loader = TagAlbumLoader(albumId: albumId) { [unowned self] success, error, _ in
            songs = self.loader?.songs ?? [Song]()
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
