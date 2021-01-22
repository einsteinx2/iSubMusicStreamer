//
//  TagAlbumLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

final class TagAlbumLoader: AbstractAPILoader {
    @Injected private var store: Store

    let serverId: Int
    let tagAlbumId: Int
    
    private(set) var songIds = [Int]()
    
    init(serverId: Int, tagAlbumId: Int, delegate: APILoaderDelegate? = nil, callback: LoaderCallback? = nil) {
        self.serverId = serverId
        self.tagAlbumId = tagAlbumId
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .tagAlbum }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: "getAlbum", parameters: ["id": tagAlbumId])
    }
    
    override func processResponse(data: Data) {
        songIds.removeAll()
        
        let root = RXMLElement(fromXMLData: data)
        guard root.isValid else {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
            return
        }
        
        if let error = root.child("error"), error.isValid {
            informDelegateLoadingFailed(error: NSError(subsonicXMLResponse: error))
            return
        }
        
        guard store.deleteTagSongs(serverId: serverId, tagAlbumId: tagAlbumId) else {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_Database)))
            return
        }
        
        guard let album = root.child("album"), album.isValid else {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_IncorrectXMLResponse)))
            return
        }
        
        let tagAlbum = TagAlbum(serverId: serverId, element: album)
        guard store.add(tagAlbum: tagAlbum) else {
            self.informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_Database)))
            return
        }
        
        root.iterate("album") { element in
            let song = Song(serverId: self.serverId, element: element)
            let isVideoSupported = self.store.server(id: self.serverId)?.isVideoSupported ?? false
            if song.path != "" && (isVideoSupported || !song.isVideo) {
                // Fix for pdfs showing in directory listing
                // TODO: See if this is still necessary
                if song.suffix.lowercased() != "pdf" {
                    guard self.store.add(tagSong: song) else {
                        self.informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_Database)))
                        return
                    }
                    
                    self.songIds.append(song.id)
                }
            }
        }
        
        informDelegateLoadingFinished()
    }
}
