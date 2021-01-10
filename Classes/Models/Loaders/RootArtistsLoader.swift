//
//  RootArtistsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/6/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class RootArtistsLoader: SUSLoader {
    @Injected private var store: Store
    
    var serverId = Settings.shared().currentServerId
    var mediaFolderId = MediaFolder.allFoldersId
    
    var metadata: RootListMetadata?
    var tableSections = [TableSection]()
    var tagArtistIds = [Int]()
    
    // MARK: SUSLoader Overrides
    
    override var type: SUSLoaderType { SUSLoaderType_RootArtists }
        
    override func createRequest() -> URLRequest? {
        var parameters: [AnyHashable: Any]?
        if mediaFolderId != MediaFolder.allFoldersId {
            parameters = ["musicFolderId": mediaFolderId]
        }
        return NSMutableURLRequest(susAction: "getArtists", parameters: parameters) as URLRequest
    }
    
    override func processResponse() {
        guard let receivedData = receivedData else { return }
        
        metadata = nil
        tableSections.removeAll()
        tagArtistIds.removeAll()
        let root = RXMLElement(fromXMLData: receivedData)
        if !root.isValid {
            informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            let error = root.child("error")
            if let error = error, error.isValid {
                informDelegateLoadingFailed(NSError(subsonicXMLResponse: error))
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
                    informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_Database)))
                }
            }
        }
    }
}