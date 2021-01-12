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

final class TagAlbumLoader: APILoader {
    @Injected private var store: Store

    override var type: APILoaderType { .tagAlbum }
    
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
    
    override func processResponse(data: Data) {
        songIds.removeAll()
        let root = RXMLElement(fromXMLData: data)
        if !root.isValid {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(error: NSError(subsonicXMLResponse: error))
            } else {
                if store.deleteTagSongs(serverId: serverId, tagAlbumId: tagAlbumId) {
                    var songOrder = 0
                    root.iterate("album.song") { element in
                        let song = Song(serverId: self.serverId, element: element)
                        if song.path != "" && (Settings.shared().currentServer.isVideoSupported || !song.isVideo) {
                            // Fix for pdfs showing in directory listing
                            // TODO: See if this is still necessary
                            if song.suffix.lowercased() != "pdf" {
                                if self.store.add(tagSong: song) {
                                    self.songIds.append(song.id)
                                    songOrder += 1
                                } else {
                                    self.informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_Database)))
                                    return
                                }
                            }
                        }
                    }
                    informDelegateLoadingFinished()
                } else {
                    informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_Database)))
                }
            }
        }
    }
}
