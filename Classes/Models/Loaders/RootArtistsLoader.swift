//
//  RootArtistsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/6/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class RootArtistsLoader: AbstractAPILoader {
    @Injected private var store: Store
    
    let serverId: Int
    let mediaFolderId: Int
    
    private(set) var metadata: RootListMetadata?
    private(set) var tableSections = [TableSection]()
    private(set) var tagArtistIds = [Int]()
    
    init(serverId: Int, mediaFolderId: Int, delegate: APILoaderDelegate? = nil, callback: LoaderCallback? = nil) {
        self.serverId = serverId
        self.mediaFolderId = mediaFolderId
        super.init(delegate: delegate, callback: callback)
    }
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .rootArtists }
        
    override func createRequest() -> URLRequest? {
        var parameters: [String: Any]?
        if mediaFolderId != MediaFolder.allFoldersId {
            parameters = ["musicFolderId": mediaFolderId]
        }
        return URLRequest(serverId: serverId, subsonicAction: "getArtists", parameters: parameters)
    }
    
    override func processResponse(data: Data) {
        metadata = nil
        tableSections.removeAll()
        tagArtistIds.removeAll()
        let root = RXMLElement(fromXMLData: data)
        if !root.isValid {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(error: NSError(subsonicXMLResponse: error))
            } else {
                if store.deleteTagArtists(serverId: serverId, mediaFolderId: mediaFolderId) {
                    var rowCount = 0
                    var sectionCount = 0
                    var rowIndex = 0
                    root.iterate("artists.index") { e in
                        sectionCount = 0
                        rowIndex = rowCount
                        e.iterate("artist") { artist in
                            // Add the artist to the DB
                            let tagArtist = TagArtist(serverId: self.serverId, element: artist)
                            if self.store.add(tagArtist: tagArtist, mediaFolderId: self.mediaFolderId) {
                                self.tagArtistIds.append(tagArtist.id)
                                rowCount += 1
                                sectionCount += 1
                            }
                        }
                        
                        let section = TableSection(serverId: self.serverId,
                                                   mediaFolderId: self.mediaFolderId,
                                                   name: e.attribute("name").stringXML,
                                                   position: rowIndex,
                                                   itemCount: sectionCount)
                        if self.store.add(tagArtistSection: section) {
                            self.tableSections.append(section)
                        }
                    }
                    
                    // Update the metadata
                    let metadata = RootListMetadata(serverId: self.serverId, mediaFolderId: mediaFolderId, itemCount: rowCount, reloadDate: Date())
                    _ = store.add(tagArtistListMetadata: metadata)
                    
                    self.metadata = metadata
                    informDelegateLoadingFinished()
                } else {
                    informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_Database)))
                }
            }
        }
    }
}
