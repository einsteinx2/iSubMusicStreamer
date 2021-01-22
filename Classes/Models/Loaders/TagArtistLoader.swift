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
    
    private let serverId: Int
    private let tagArtistId: Int
    
    private(set) var tagAlbumIds = [Int]()
    
    init(serverId: Int, tagArtistId: Int, callback: LoaderCallback? = nil) {
        self.serverId = serverId
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
        guard root.isValid else {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
            return
        }
        
        if let error = root.child("error"), error.isValid {
            informDelegateLoadingFailed(error: NSError(subsonicXMLResponse: error))
            return
        }
        
        guard store.deleteTagAlbums(serverId: serverId, tagArtistId: tagArtistId) else  {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_Database)))
            return
        }
        
        guard let artist = root.child("artist"), artist.isValid else {
            self.informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_IncorrectXMLResponse)))
            return
        }
            
        let tagArtist = TagArtist(serverId: serverId, element: artist)
        guard self.store.add(tagArtist: tagArtist, mediaFolderId: MediaFolder.allFoldersId) else {
            self.informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_Database)))
            return
        }
        
        artist.iterate("album") { element in
            let tagAlbum = TagAlbum(serverId: self.serverId, element: element)
            guard self.store.add(tagAlbum: tagAlbum) else {
                self.informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_Database)))
                return
            }
            
            self.tagAlbumIds.append(tagAlbum.id)
        }
        
        informDelegateLoadingFinished()
    }
}
