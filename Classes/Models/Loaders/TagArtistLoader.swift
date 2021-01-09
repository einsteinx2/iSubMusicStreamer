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

final class TagArtistLoader: SUSLoader {
    @Injected private var store: Store
    
    override var type: SUSLoaderType { return SUSLoaderType_TagArtist }
    
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
    
    override func createRequest() -> URLRequest? {
        return NSMutableURLRequest(susAction: "getArtist", parameters: ["id": tagArtistId]) as URLRequest
    }
    
    override func processResponse() {
        guard let receivedData = receivedData else { return }
        
        tagAlbumIds.removeAll()
        let root = RXMLElement(fromXMLData: receivedData)
        if !root.isValid {
            informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(NSError(subsonicXMLResponse: error))
            } else {
                if store.deleteTagAlbums(serverId: serverId, tagArtistId: tagArtistId) {
                    var albumOrder = 0
                    root.iterate("artist.album") { element in
                        let tagAlbum = TagAlbum(serverId: self.serverId, element: element)
                        if self.store.add(tagAlbum: tagAlbum) {
                            self.tagAlbumIds.append(tagAlbum.id)
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
}
