//
//  TagArtistLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

final class TagArtistLoader: APILoader {
    @Injected private var store: Store
    
    var serverId = Settings.shared().currentServerId
    let tagArtistId: Int
    
    var tagAlbumIds = [Int]()
    
    init(tagArtistId: Int) {
        self.tagArtistId = tagArtistId
        super.init()
    }
    
    init(tagArtistId: Int, callback: @escaping LoaderCallback) {
        self.tagArtistId = tagArtistId
        super.init(callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .tagArtist }
    
    override func createRequest() -> URLRequest? {
        URLRequest(serverId: serverId, subsonicAction: "getArtist", parameters: ["id": tagArtistId])
    }
    
    override func processResponse(data: Data) {
        tagAlbumIds.removeAll()
        let root = RXMLElement(fromXMLData: data)
        if !root.isValid {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(error: NSError(subsonicXMLResponse: error))
            } else {
                if store.deleteTagAlbums(serverId: serverId, tagArtistId: tagArtistId) {
                    var albumOrder = 0
                    root.iterate("artist.album") { element in
                        let tagAlbum = TagAlbum(serverId: self.serverId, element: element)
                        if self.store.add(tagAlbum: tagAlbum) {
                            self.tagAlbumIds.append(tagAlbum.id)
                            albumOrder += 1
                        } else {
                            self.informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_Database)))
                            return
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
