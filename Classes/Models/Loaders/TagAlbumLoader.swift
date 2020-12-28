//
//  TagAlbumLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

final class TagAlbumLoader: SUSLoader {
    override var type: SUSLoaderType { return SUSLoaderType_TagAlbum }
    
    let albumId: String
    
    private(set) var songs = [Song]()
    
    init(albumId: String) {
        self.albumId = albumId
        super.init()
    }
    
    init(albumId: String, callback: @escaping SUSLoaderCallback) {
        self.albumId = albumId
        super.init(callback: callback)
    }
    
    override func createRequest() -> URLRequest {
        return NSMutableURLRequest(susAction: "getAlbum", parameters: ["id": albumId]) as URLRequest
    }
    
    override func processResponse() {
        guard let receivedData = receivedData else { return }
        
        songs.removeAll()
        let root = RXMLElement(fromXMLData: receivedData)
        if !root.isValid {
            informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(NSError(subsonicXMLResponse: error))
            } else {
                if resetDb(albumId: albumId) {
                    var songOrder = 0
                    root.iterate("album.song") { element in
                        let song = Song(rxmlElement: element)
                        if song.path != nil && (Settings.shared().isVideoSupported || !song.isVideo) {
                            // Fix for pdfs showing in directory listing
                            // TODO: See if this is still necessary
                            if song.suffix?.lowercased() != "pdf" {
                                if self.cacheSong(albumId: self.albumId, song: song, itemOrder: songOrder) {
                                    self.songs.append(song)
                                    songOrder += 1
                                } else {
                                    self.informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_Database)))
                                    return
                                }
                            }
                        }
                    }
                    informDelegateLoadingFinished()
                } else {
                    informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_Database)))
                }
            }
        }
    }
    
    private func resetDb(albumId: String) -> Bool {
        var success = true
        Database.shared().serverDbQueue?.inDatabase { db in
            if !db.executeUpdate("DELETE FROM tagSong WHERE albumId = ?", albumId) {
                DDLogError("[TagAlbumLoader] Error resetting tagSong cache table for albumId \(albumId) - \(db.lastErrorCode()): \(db.lastErrorMessage())")
                success = false
            }
        }
        return success
    }
    
    private func cacheSong(albumId: String, song: Song, itemOrder: Int) -> Bool {
        var success = true
        Database.shared().serverDbQueue?.inDatabase { db in
            let query = "INSERT INTO tagSong (albumId, itemOrder, songId) VALUES (?, ?, ?)"
            success = db.executeUpdate(query, albumId, itemOrder, song.songId ?? NSNull())
            if !success {
                DDLogError("[TagAlbumLoader] Error caching song \(db.lastErrorCode()): \(db.lastErrorMessage())")
            }
        }
        return success && song.updateMetadataCache()
    }
}

