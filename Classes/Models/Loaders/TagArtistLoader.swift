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
    
    init(artistId: String, callback: @escaping SUSLoaderCallback) {
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
                resetDb()
                var albumOrder = 0
                root.iterate("artist.album") { element in
                    let tagAlbum = TagAlbum(element: element)
                    self.tagAlbums.append(tagAlbum)
                    self.cacheAlbum(tagAlbum: tagAlbum, itemOrder: albumOrder)
                    albumOrder += 1
                }
                informDelegateLoadingFinished()
            }
        }
    }
    
    private func resetDb() {
        Database.shared().serverDbQueue?.inDatabase { db in
            if !db.executeUpdate("DELETE FROM tagAlbum WHERE artistId = ?", artistId) {
                DDLogError("[TagArtistLoader] Error resetting tagAlbum cache table \(db.lastErrorCode()): \(db.lastErrorMessage())")
            }
        }
    }
    
    private func cacheAlbum(tagAlbum: TagAlbum, itemOrder: Int) {
        Database.shared().serverDbQueue?.inDatabase { db in
            if !db.executeUpdate("INSERT INTO tagAlbum (artistId, albumId, itemOrder, name, coverArtId, tagArtistName, songCount, duration, playCount, year) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", artistId, tagAlbum.id, itemOrder, tagAlbum.name, tagAlbum.coverArtId ?? NSNull(), tagAlbum.tagArtistName ?? NSNull(), tagAlbum.songCount, tagAlbum.duration, tagAlbum.playCount, tagAlbum.year) {
                DDLogError("[TagArtistLoader] Error caching tagAlbum \(db.lastErrorCode()): \(db.lastErrorMessage())")
            }
        }
    }
}
