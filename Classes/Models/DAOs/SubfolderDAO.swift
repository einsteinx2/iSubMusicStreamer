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
    
    var serverId = Settings.shared().currentServerId
    private let parentFolderId: Int
    private var loader: SubfolderLoader?
    private var metadata: FolderMetadata?
    private var folderAlbumIds = [Int]()
    private var songIds = [Int]()
    
    @objc weak var delegate: APILoaderDelegate?
    
    @objc var hasLoaded: Bool { metadata != nil }
    @objc var folderCount: Int { metadata?.folderCount ?? 0 }
    @objc var songCount: Int { metadata?.songCount ?? 0 }
    @objc var duration: Int { metadata?.duration ?? 0 }
    
    @objc init(parentFolderId: Int, delegate: APILoaderDelegate?) {
        self.parentFolderId = parentFolderId
        self.delegate = delegate
        super.init()
        loadFromCache()
    }
    
    deinit {
        loader?.cancelLoad()
    }
    
    private func loadFromCache() {
        metadata = store.folderMetadata(serverId: serverId, parentFolderId: parentFolderId)
        if metadata != nil {
            folderAlbumIds = store.folderAlbumIds(serverId: serverId, parentFolderId: parentFolderId)
            songIds = store.songIds(serverId: serverId, parentFolderId: parentFolderId)
        } else {
            folderAlbumIds.removeAll()
            songIds.removeAll()
        }
    }
    
    @objc func folderAlbum(indexPath: IndexPath) -> FolderAlbum? {
        guard indexPath.row < folderAlbumIds.count else { return nil }
        return store.folderAlbum(serverId: serverId, id: folderAlbumIds[indexPath.row])
    }
    
    @objc func song(indexPath: IndexPath) -> Song? {
        guard indexPath.row < songIds.count else { return nil }
        return store.song(serverId: serverId, id: songIds[indexPath.row])
    }
    
    @objc func playSong(indexPath: IndexPath) -> Song? {
        guard indexPath.section == 1, indexPath.row < songIds.count else { return nil }
        return store.playSong(position: indexPath.row, songIds: songIds, serverId: serverId)
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

@objc extension SubfolderDAO: APILoaderManager {
    func startLoad() {
        loader = SubfolderLoader(parentFolderId: parentFolderId) { [unowned self] success, error in
            if let loader = loader {
                metadata = loader.folderMetadata
                folderAlbumIds = loader.folderAlbumIds
                songIds = loader.songIds
            }
            
            loader = nil
            if success {
                delegate?.loadingFinished(loader: nil)
            } else {
                delegate?.loadingFailed(loader: nil, error: error as NSError?)
            }
        }
        loader?.startLoad()
    }
    
    func cancelLoad() {
        loader?.cancelLoad()
        loader = nil
    }
}
