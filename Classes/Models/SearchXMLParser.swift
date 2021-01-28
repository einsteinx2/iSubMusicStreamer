//
//  SearchXMLParser.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

final class SearchXMLParser {
    @Injected private var store: Store
        
    let serverId: Int
    
    private(set) var folderArtists = [FolderArtist]()
    private(set) var folderAlbums = [FolderAlbum]()
    private(set) var songs = [Song]()
    
    init(serverId: Int, data: Data) {
        self.serverId = serverId
        let root = RXMLElement(fromXMLData: data)
        if !root.isValid {
            // TODO: Handle this error in the UI
            DDLogError("[SearchXMLParser] Error parsing search results: \(APIError.responseNotXML)")
        } else {
            if let error = root.child("error"), error.isValid {
                // TODO: Handle this error in the UI
                DDLogError("[SearchXMLParser] Subsonic error: \(SubsonicError(element: error))")
            } else {
                let isNewSearchSupported = store.server(id: serverId)?.isNewSearchSupported ?? false
                if isNewSearchSupported {
                    root.iterate("searchResult2.artist") { element, _ in
                        self.folderArtists.append(FolderArtist(serverId: serverId, element: element))
                    }
                    root.iterate("searchResult2.album") { element, _ in
                        self.folderAlbums.append(FolderAlbum(serverId: serverId, element: element))
                    }
                    root.iterate("searchResult2.song") { element, _ in
                        let isVideo = element.attribute("isVideo")
                        if isVideo != "true" {
                            let song = Song(serverId: serverId, element: element)
                            if song.path != "" {
                                self.songs.append(song)
                            }
                        }
                    }
                } else {
                    root.iterate("searchResult.match") { element, _ in
                        let isVideo = element.attribute("isVideo")
                        if isVideo != "true" {
                            let song = Song(serverId: serverId, element: element)
                            if song.path != "" {
                                self.songs.append(song)
                            }
                        }
                    }
                }
            }
        }
    }
}
