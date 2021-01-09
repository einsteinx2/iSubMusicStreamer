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

final class TagAlbumLoader: SUSLoader {
    @Injected private var store: Store

    override var type: SUSLoaderType { return SUSLoaderType_TagAlbum }
    
    var serverId = Settings.shared().currentServerId
    let tagAlbumId: Int
    
    private(set) var songIds = [Int]()
    
    init(tagAlbumId: Int) {
        self.tagAlbumId = tagAlbumId
        super.init()
    }
    
    init(tagAlbumId: Int, callback: @escaping LoaderCallback) {
        self.tagAlbumId = tagAlbumId
        super.init(callback: callback)
    }
    
    override func createRequest() -> URLRequest? {
        return NSMutableURLRequest(susAction: "getAlbum", parameters: ["id": tagAlbumId]) as URLRequest
    }
    
    override func processResponse() {
        guard let receivedData = receivedData else { return }
        
        songIds.removeAll()
        let root = RXMLElement(fromXMLData: receivedData)
        if !root.isValid {
            informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(NSError(subsonicXMLResponse: error))
            } else {
                if store.deleteTagSongs(serverId: serverId, tagAlbumId: tagAlbumId) {
                    var songOrder = 0
                    root.iterate("album.song") { element in
                        let song = NewSong(serverId: self.serverId, element: element)
                        if song.path != "" && (Settings.shared().currentServer.isVideoSupported || !song.isVideo) {
                            // Fix for pdfs showing in directory listing
                            // TODO: See if this is still necessary
                            if song.suffix.lowercased() != "pdf" {
                                if self.store.add(tagSong: song) {
                                    self.songIds.append(song.id)
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
}
