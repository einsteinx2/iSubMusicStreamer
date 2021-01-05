//
//  TagArtistLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

final class TagArtistLoader: SUSLoader {
    override var type: SUSLoaderType { return SUSLoaderType_TagArtist }
    
    let artistId: String
    
    private(set) var tagAlbums = [TagAlbum]()
    
    init(artistId: String) {
        self.artistId = artistId
        super.init()
    }
    
    init(artistId: String, callback: @escaping LoaderCallback) {
        self.artistId = artistId
        super.init(callback: callback)
    }
    
    override func createRequest() -> URLRequest {
        return NSMutableURLRequest(susAction: "getArtist", parameters: ["id": artistId]) as URLRequest
    }
    
    override func processResponse() {
        guard let receivedData = receivedData else { return }
        
        tagAlbums.removeAll()
        let root = RXMLElement(fromXMLData: receivedData)
        if !root.isValid {
            informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(NSError(subsonicXMLResponse: error))
            } else {
                if resetDb(artistId: artistId) {
                    var albumOrder = 0
                    root.iterate("artist.album") { element in
                        let tagAlbum = TagAlbum(element: element)
                        if self.cacheAlbum(artistId: self.artistId, tagAlbum: tagAlbum, itemOrder: albumOrder) {
                            self.tagAlbums.append(tagAlbum)
                            albumOrder += 1
                        } else {
                            self.informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_Database)))
                            return
                        }
                    }
                    informDelegateLoadingFinished()
                } else {
                    informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_Database)))
                }
            }
        }
    }
    
    private func resetDb(artistId: String) -> Bool {
        var success = true
        DatabaseOld.shared().serverDbQueue?.inDatabase { db in
            if !db.executeUpdate("DELETE FROM tagAlbum WHERE artistId = ?", artistId) {
                DDLogError("[TagArtistLoader] Error resetting tagAlbum cache table for artistId \(artistId) - \(db.lastErrorCode()): \(db.lastErrorMessage())")
                success = false
            }
        }
        return success
    }
    
    private func cacheAlbum(artistId: String, tagAlbum: TagAlbum, itemOrder: Int) -> Bool {
        var success = true
        DatabaseOld.shared().serverDbQueue?.inDatabase { db in
            let query = "INSERT INTO tagAlbum (artistId, albumId, itemOrder, name, coverArtId, tagArtistName, songCount, duration, playCount, year) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            success = db.executeUpdate(query, artistId, tagAlbum.id, itemOrder, tagAlbum.name, tagAlbum.coverArtId ?? NSNull(), tagAlbum.tagArtistName ?? NSNull(), tagAlbum.songCount, tagAlbum.duration, tagAlbum.playCount, tagAlbum.year)
            if !success {
                DDLogError("[TagArtistLoader] Error caching tagAlbum \(db.lastErrorCode()): \(db.lastErrorMessage())")
            }
        }
        return success
    }
}
