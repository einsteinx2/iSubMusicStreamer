//
//  RootFoldersLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class RootFoldersLoader: SUSLoader {
    @Injected private var store: Store
    
    var mediaFolderId = MediaFolder.allFoldersId
    
    var metadata: RootListMetadata?
    var tableSections = [TableSection]()
    var folderArtistIds = [Int]()
    
    // MARK: SUSLoader Overrides
    
    override var type: SUSLoaderType { SUSLoaderType_RootArtists }
        
    override func createRequest() -> URLRequest {
        var parameters: [AnyHashable: Any]?
        if mediaFolderId != MediaFolder.allFoldersId {
            parameters = ["musicFolderId": mediaFolderId]
        }
        return NSMutableURLRequest(susAction: "getIndexes", parameters: parameters) as URLRequest
    }
    
    override func processResponse() {
        guard let receivedData = receivedData else { return }
        
        var sections = [TableSection]()
        var folderIds = [Int]()
        let root = RXMLElement(fromXMLData: receivedData)
        if !root.isValid {
            informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_NotXML)))
        } else {
            let error = root.child("error")
            if let error = error, error.isValid {
                informDelegateLoadingFailed(NSError(subsonicXMLResponse: error))
            } else {
                if store.deleteFolderArtists(mediaFolderId: mediaFolderId) {
                    var rowCount = 0
                    var sectionCount = 0
                    var rowIndex = 0
                    
                    // Process shortcuts (basically just custom folder artists)
                    root.iterate("indexes.shortcut") { e in
                        let shortcut = FolderArtist(element: e)
                        if self.store.add(folderArtist: shortcut, mediaFolderId: self.mediaFolderId) {
                            folderIds.append(shortcut.id)
                            rowCount += 1
                            sectionCount += 1
                        }
                    }
                    if sectionCount > 0 {
                        let section = TableSection(mediaFolderId: self.mediaFolderId,
                                                   name: "*",
                                                   position: rowIndex,
                                                   itemCount: sectionCount)
                        if store.add(folderArtistSection: section) {
                            sections.append(section)
                        }
                    }
                    
                    // Process folder artists
                    root.iterate("indexes.index") { e in
                        sectionCount = 0
                        rowIndex = rowCount
                        e.iterate("artist") { artist in
                            // Add the artist to the DB
                            let folderArtist = FolderArtist(element: artist)
                            // Prevent inserting .AppleDouble folders
                            if folderArtist.name != ".AppleDouble" && self.store.add(folderArtist: folderArtist, mediaFolderId: self.mediaFolderId) {
                                folderIds.append(folderArtist.id)
                                rowCount += 1
                                sectionCount += 1
                            }
                        }
                        
                        let section = TableSection(mediaFolderId: self.mediaFolderId,
                                                   name: e.attribute("name").stringXML,
                                                   position: rowIndex,
                                                   itemCount: sectionCount)
                        if self.store.add(folderArtistSection: section) {
                            sections.append(section)
                        }
                    }
                    
                    // Update the metadata
                    let metadata = RootListMetadata(mediaFolderId: mediaFolderId, itemCount: rowCount, reloadDate: Date())
                    _ = store.add(folderArtistListMetadata: metadata)
                    
                    self.metadata = metadata
                    self.tableSections = sections
                    self.folderArtistIds = folderIds
                    informDelegateLoadingFinished()
                } else {
                    informDelegateLoadingFailed(NSError(ismsCode: Int(ISMSErrorCode_Database)))
                }
            }
        }
    }
}
