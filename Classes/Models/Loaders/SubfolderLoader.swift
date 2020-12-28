//
//  SubFolderLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

final class SubfolderLoader: SUSLoader {
    override var type: SUSLoaderType { return SUSLoaderType_SubFolders }
    
    let folderId: String
    let folderArtist: FolderArtist // TODO: Get rid of this hack
    private(set) var folderMetadata: FolderMetadata?
    
    init(folderId: String, folderArtist: FolderArtist) {
        self.folderId = folderId
        self.folderArtist = folderArtist
        super.init()
    }
    
    init(folderId: String, folderArtist: FolderArtist, callback: @escaping SUSLoaderCallback) {
        self.folderId = folderId
        self.folderArtist = folderArtist
        super.init(callback: callback)
    }
    
    override func createRequest() -> URLRequest {
        return NSMutableURLRequest(susAction: "getMusicDirectory", parameters: ["id": folderId]) as URLRequest
    }
    
    override func processResponse() {
        guard let receivedData = receivedData else { return }
        
        let root = RXMLElement(fromXMLData: receivedData)
        if !root.isValid {
            informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(NSError(subsonicXMLResponse: error))
            } else {
                if resetDb() {
                    var songCount = 0
                    var duration = 0
                    
                    var subfolders = [FolderAlbum]()//NSMutableArray()
                    root.iterate("directory.child") { element in
                        if element.attribute("isDir") == "true" {
                            let folderAlbum = FolderAlbum(element: element, folderArtist: self.folderArtist)
                            if folderAlbum.title != ".AppleDouble" {
                                subfolders.append(folderAlbum)
                            }
                        } else {
                            let song = Song(rxmlElement: element)
                            if song.path != nil && (Settings.shared().isVideoSupported || !song.isVideo) {
                                // Fix for pdfs showing in directory listing
                                // TODO: See if this is still necessary
                                if song.suffix?.lowercased() != "pdf" {
                                    if self.cacheSong(folderId: self.folderId, song: song, itemOrder: songCount) {
                                        songCount += 1
                                        duration += song.duration?.intValue ?? 0
                                    } else {
                                        self.informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_Database)))
                                        return
                                    }
                                }
                            }
                        }
                    }
                    
                    // Hack for Subsonic 4.7 breaking alphabetical order
                    subfolders.sort { $0.title.caseInsensitiveCompare($1.title) != .orderedDescending }
                    var subfolderCount = 0
                    for folderAlbum in subfolders {
                        if cacheFolder(folderId: folderId, folderAlbum: folderAlbum, itemOrder: subfolderCount) {
                            subfolderCount += 1
                        } else {
                            informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_Database)))
                            return
                        }
                    }
                    
                    let metadata = FolderMetadata(folderId: folderId, subfolderCount: subfolderCount, songCount: songCount, duration: duration)
                    if !cacheMetadata(metadata: metadata) {
                        informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_Database)))
                        return
                    }
                    
                    folderMetadata = metadata
                    informDelegateLoadingFinished()
                } else {
                    informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_Database)))
                }
            }
        }
    }
    
    private func resetDb() -> Bool {
        var success = true
        Database.shared().serverDbQueue?.inDatabase { db in
            if db.beginTransaction() {
                if !db.executeUpdate("DELETE FROM folderAlbum WHERE folderId = ?", folderId) {
                    DDLogError("[SubfolderLoader] Error resetting tagSong cache table for folderId \(folderId), failed to delete from folderAlbum - \(db.lastErrorCode()): \(db.lastErrorMessage())")
                    db.rollback()
                    success = false
                    return
                }
                
                if !db.executeUpdate("DELETE FROM folderSong WHERE folderId = ?", folderId) {
                    DDLogError("[SubfolderLoader] Error resetting tagSong cache table for folderId \(folderId), failed to delete from folderSong - \(db.lastErrorCode()): \(db.lastErrorMessage())")
                    db.rollback()
                    success = false
                    return
                }
                
                if !db.executeUpdate("DELETE FROM folderMetadata WHERE folderId = ?", folderId) {
                    DDLogError("[SubfolderLoader] Error resetting tagSong cache table for folderId \(folderId), failed to delete from folderMetadata - \(db.lastErrorCode()): \(db.lastErrorMessage())")
                    db.rollback()
                    success = false
                    return
                }
                
                if !db.commit() {
                    DDLogError("[SubfolderLoader] Error resetting tagSong cache table for folderId \(folderId), failed to delete from folderMetadata - \(db.lastErrorCode()): \(db.lastErrorMessage())")
                    db.rollback()
                    success = false
                    return
                }
            } else {
                DDLogError("[SubfolderLoader] Error resetting tagSong cache table for folderId \(folderId), failed to commit transaction - \(db.lastErrorCode()): \(db.lastErrorMessage())")
                success = false
            }
        }
        return success
    }
    
    private func cacheFolder(folderId: String, folderAlbum: FolderAlbum, itemOrder: Int) -> Bool {
        var success = true
        Database.shared().serverDbQueue?.inDatabase { db in
            let query = "INSERT INTO folderAlbum (folderId, subfolderId, itemOrder, title, coverArtId, folderArtistId, folderArtistName, tagAlbumName, playCount, year) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            success = db.executeUpdate(query, folderId, folderAlbum.id, itemOrder, folderAlbum.title, folderAlbum.coverArtId ?? NSNull(),folderAlbum.folderArtistId, folderAlbum.folderArtistName, folderAlbum.tagAlbumName ?? NSNull(), folderAlbum.playCount, folderAlbum.year)
            if !success {
                DDLogError("[SubfolderLoader] Error caching folderAlbum \(db.lastErrorCode()): \(db.lastErrorMessage())")
            }
        }
        return success
    }
    
    private func cacheSong(folderId: String, song: Song, itemOrder: Int) -> Bool {
        var success = true
        Database.shared().serverDbQueue?.inDatabase { db in
            let query = "INSERT INTO folderSong (folderId, itemOrder, songId) VALUES (?, ?, ?)"
            success = db.executeUpdate(query, folderId, itemOrder, song.songId ?? NSNull())
            if !success {
                DDLogError("[SubfolderLoader] Error caching song \(db.lastErrorCode()): \(db.lastErrorMessage())")
            }
        }
        return success && song.updateMetadataCache()
    }
    
    private func cacheMetadata(metadata: FolderMetadata) -> Bool {
        var success = true
        Database.shared().serverDbQueue?.inDatabase { db in
            let query = "INSERT INTO folderMetadata (folderId, subfolderCount, songCount, duration) VALUES (?, ?, ?, ?)"
            success = db.executeUpdate(query, metadata.folderId, metadata.subfolderCount, metadata.songCount, metadata.duration)
            if !success {
                DDLogError("[SubfolderLoader] Error caching metadata \(db.lastErrorCode()): \(db.lastErrorMessage())")
            }
        }
        return success
    }
}
