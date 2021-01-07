//
//  SubfolderDAO.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

@objc final class SubfolderDAO: NSObject {
    private let folderId: Int
    private var loader: SubfolderLoader?
    private var metadata: FolderMetadata?
    
    @objc weak var delegate: SUSLoaderDelegate?
    
    @objc var hasLoaded: Bool { metadata != nil }
    @objc var subfolderCount: Int { metadata?.subfolderCount ?? 0 }
    @objc var songCount: Int { metadata?.songCount ?? 0 }
    @objc var duration: Int { metadata?.duration ?? 0 }
    
    @objc init(folderId: Int, delegate: SUSLoaderDelegate?) {
        self.folderId = folderId
        self.delegate = delegate
        super.init()
        metadata = folderMetadata(folderId: folderId)
    }
    
    deinit {
        loader?.cancelLoad()
    }
    
    private func folderMetadata(folderId: Int) -> FolderMetadata? {
        var folderMetadata: FolderMetadata?
        DatabaseOld.shared().serverDbQueue?.inDatabase { db in
            if let result = db.executeQuery("SELECT * FROM folderMetadata WHERE folderId = ?", folderId), result.next() {
                folderMetadata = FolderMetadata(result: result)
            } else if db.hadError() {
                DDLogError("[SubfolderDAO] Error reading folder \(folderId) metadata - \(db.lastErrorCode()): \(db.lastErrorMessage())");
            }
        }
        return folderMetadata
    }
    
    @objc func folderAlbum(row: Int) -> FolderAlbum? {
        var folderAlbum: FolderAlbum?
        DatabaseOld.shared().serverDbQueue?.inDatabase { db in
            if let result = db.executeQuery("SELECT * FROM folderAlbum WHERE folderId = ? AND itemOrder = ?", folderId, row), result.next() {
                folderAlbum = FolderAlbum(result: result)
            } else if db.hadError() {
                DDLogError("[SubfolderDAO] Error reading folderAlbum - \(db.lastErrorCode()): \(db.lastErrorMessage())");
            }
        }
        return folderAlbum
    }
    
    @objc func song(row: Int) -> Song? {
        var song: Song?
        DatabaseOld.shared().serverDbQueue?.inDatabase { db in
            let query = """
                SELECT song.*
                FROM folderSong
                JOIN song ON folderSong.songId = song.songId
                WHERE folderSong.folderId = ? AND folderSong.itemOrder = ?
            """
            if let result = db.executeQuery(query, folderId, row), result.next() {
                song = Song(result: result)
            } else if db.hadError() {
                DDLogError("[SubfolderDAO] Error reading song - \(db.lastErrorCode()): \(db.lastErrorMessage())");
            }
        }
        return song
    }
    
    @objc func playSong(row: Int) -> Song? {
        // Clear the current playlist
        if Settings.shared().isJukeboxEnabled {
            DatabaseOld.shared().resetJukeboxPlaylist()
            Jukebox.shared().clearRemotePlaylist()
        } else {
            DatabaseOld.shared().resetCurrentPlaylistDb()
        }
        
        // Add the songs to the playlist
        DatabaseOld.shared().serverDbQueue?.inDatabase { db in
            let query = """
                INSERT INTO currentPlaylist
                SELECT songId, itemOrder
                FROM folderSong
                WHERE folderId = ?
                ORDER BY itemOrder ASC
            """
            if !db.executeUpdate(query, folderId) {
                DDLogError("[SubfolderDAO] Error inserting folder \(folderId)'s songs into current playlist \(db.lastErrorCode()): \(db.lastErrorMessage())");
            }
        }
        
        // Set player defaults
        PlayQueue.shared().isShuffle = false
        
        NotificationCenter.postNotificationToMainThread(name: ISMSNotification_CurrentPlaylistSongsQueued)
        
        // Start the song
        return Music.shared().playSong(atPosition: row)
    }
    
    @objc func sectionInfo() -> [Any]? {
        if let metadata = metadata, metadata.subfolderCount > 10 {
            var sectionInfo: [Any]?
            DatabaseOld.shared().serverDbQueue?.inDatabase { db in
                _ = db.executeUpdate("DROP TABLE IF EXISTS folderIndex")
                _ = db.executeUpdate("CREATE TEMPORARY TABLE folderIndex (title TEXT, order INTEGER)")
                _ = db.executeUpdate("INSERT INTO folderIndex SELECT title, order FROM folderAlbum WHERE folderId = ?", folderId)
                _ = db.executeUpdate("CREATE INDEX folderIndex_title ON folderIndex (title)")
                sectionInfo = DatabaseOld.shared().sectionInfoFromOrderColumnTable("folderIndex", database: db, column: "title")
            }
            return sectionInfo
        }
        return nil
    }
}

@objc extension SubfolderDAO: SUSLoaderManager {
    func startLoad() {
        loader = SubfolderLoader(folderId: folderId) { [unowned self] success, error in
            metadata = loader?.folderMetadata
            loader = nil
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
