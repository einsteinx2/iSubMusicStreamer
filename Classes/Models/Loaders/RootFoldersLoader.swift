//
//  RootFoldersLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class RootFoldersLoader: APILoader {
    @Injected private var store: Store
    
    var serverId = Settings.shared().currentServerId
    var mediaFolderId = MediaFolder.allFoldersId
    
    private(set) var metadata: RootListMetadata?
    private(set) var tableSections = [TableSection]()
    private(set) var folderArtistIds = [Int]()
    
    // MARK: APILoader Overrides
    
    override var type: APILoaderType { .rootArtists }
        
    override func createRequest() -> URLRequest? {
        var parameters: [String: Any]?
        if mediaFolderId != MediaFolder.allFoldersId {
            parameters = ["musicFolderId": mediaFolderId]
        }
        return URLRequest(serverId: serverId, subsonicAction: "getIndexes", parameters: parameters)
    }
    
    override func processResponse(data: Data) {
        metadata = nil
        tableSections.removeAll()
        folderArtistIds.removeAll()
        let root = RXMLElement(fromXMLData: data)
        if !root.isValid {
            informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            if let error = root.child("error"), error.isValid {
                informDelegateLoadingFailed(error: NSError(subsonicXMLResponse: error))
            } else {
                if store.deleteFolderArtists(serverId: serverId, mediaFolderId: mediaFolderId) {
                    var rowCount = 0
                    var sectionCount = 0
                    var rowIndex = 0
                    
                    // Process shortcuts (basically just custom folder artists)
                    root.iterate("indexes.shortcut") { e in
                        let shortcut = FolderArtist(serverId: self.serverId, element: e)
                        if self.store.add(folderArtist: shortcut, mediaFolderId: self.mediaFolderId) {
                            self.folderArtistIds.append(shortcut.id)
                            rowCount += 1
                            sectionCount += 1
                        }
                    }
                    if sectionCount > 0 {
                        let section = TableSection(serverId: self.serverId,
                                                   mediaFolderId: self.mediaFolderId,
                                                   name: "*",
                                                   position: rowIndex,
                                                   itemCount: sectionCount)
                        if store.add(folderArtistSection: section) {
                            self.tableSections.append(section)
                        }
                    }
                    
                    // Process folder artists
                    root.iterate("indexes.index") { e in
                        sectionCount = 0
                        rowIndex = rowCount
                        e.iterate("artist") { artist in
                            // Add the artist to the DB
                            let folderArtist = FolderArtist(serverId: self.serverId, element: artist)
                            // Prevent inserting .AppleDouble folders
                            if folderArtist.name != ".AppleDouble" && self.store.add(folderArtist: folderArtist, mediaFolderId: self.mediaFolderId) {
                                self.folderArtistIds.append(folderArtist.id)
                                rowCount += 1
                                sectionCount += 1
                            }
                        }
                        
                        let section = TableSection(serverId: self.serverId,
                                                   mediaFolderId: self.mediaFolderId,
                                                   name: e.attribute("name").stringXML,
                                                   position: rowIndex,
                                                   itemCount: sectionCount)
                        if self.store.add(folderArtistSection: section) {
                            self.tableSections.append(section)
                        }
                    }
                    
                    // Update the metadata
                    let metadata = RootListMetadata(serverId: self.serverId, mediaFolderId: mediaFolderId, itemCount: rowCount, reloadDate: Date())
                    _ = store.add(folderArtistListMetadata: metadata)
                    
                    self.metadata = metadata
                    informDelegateLoadingFinished()
                } else {
                    informDelegateLoadingFailed(error: NSError(ismsCode: Int(ISMSErrorCode_Database)))
                }
            }
        }
    }
}
