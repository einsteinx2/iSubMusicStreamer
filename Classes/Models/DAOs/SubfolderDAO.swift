//
//  SubfolderDAO.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

@objc final class SubfolderDAO: NSObject {
    @Injected private var store: Store
    
    private let parentFolderId: Int
    private var loader: SubfolderLoader?
    private var metadata: FolderMetadata?
    private var folderAlbumIds = [Int]()
    private var songIds = [Int]()
    
    @objc weak var delegate: SUSLoaderDelegate?
    
    @objc var hasLoaded: Bool { metadata != nil }
    @objc var folderCount: Int { metadata?.folderCount ?? 0 }
    @objc var songCount: Int { metadata?.songCount ?? 0 }
    @objc var duration: Int { metadata?.duration ?? 0 }
    
    @objc init(parentFolderId: Int, delegate: SUSLoaderDelegate?) {
        self.parentFolderId = parentFolderId
        self.delegate = delegate
        super.init()
        loadFromCache()
    }
    
    deinit {
        loader?.cancelLoad()
    }
    
    private func loadFromCache() {
        metadata = store.folderMetadata(parentFolderId: parentFolderId)
        if metadata != nil {
            folderAlbumIds = store.folderAlbumIds(parentFolderId: parentFolderId)
            songIds = store.songIds(parentFolderId: parentFolderId)
        } else {
            folderAlbumIds.removeAll()
            songIds.removeAll()
        }
    }
    
    @objc func folderAlbum(indexPath: IndexPath) -> FolderAlbum? {
        guard indexPath.row < folderAlbumIds.count else { return nil }
        return store.folderAlbum(id: folderAlbumIds[indexPath.row])
    }
    
    @objc func song(indexPath: IndexPath) -> NewSong? {
        guard indexPath.row < songIds.count else { return nil }
        return store.song(id: songIds[indexPath.row])
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
//                FROM folderSong
//                WHERE folderId = ?
//                ORDER BY itemOrder ASC
//            """
//            if !db.executeUpdate(query, folderId) {
//                DDLogError("[SubfolderDAO] Error inserting folder \(folderId)'s songs into current playlist \(db.lastErrorCode()): \(db.lastErrorMessage())");
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
    
//    @objc func sectionInfo() -> [Any]? {
//        if let metadata = metadata, metadata.subfolderCount > 10 {
//            var sectionInfo: [Any]?
//            DatabaseOld.shared().serverDbQueue?.inDatabase { db in
//                _ = db.executeUpdate("DROP TABLE IF EXISTS folderIndex")
//                _ = db.executeUpdate("CREATE TEMPORARY TABLE folderIndex (title TEXT, order INTEGER)")
//                _ = db.executeUpdate("INSERT INTO folderIndex SELECT title, order FROM folderAlbum WHERE folderId = ?", folderId)
//                _ = db.executeUpdate("CREATE INDEX folderIndex_title ON folderIndex (title)")
//                sectionInfo = DatabaseOld.shared().sectionInfoFromOrderColumnTable("folderIndex", database: db, column: "title")
//            }
//            return sectionInfo
//        }
//        return nil
//    }
}

@objc extension SubfolderDAO: SUSLoaderManager {
    func startLoad() {
        loader = SubfolderLoader(parentFolderId: parentFolderId) { [unowned self] success, error in
            if let loader = loader {
                metadata = loader.folderMetadata
                folderAlbumIds = loader.folderAlbumIds
                songIds = loader.songIds
            }
            
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
