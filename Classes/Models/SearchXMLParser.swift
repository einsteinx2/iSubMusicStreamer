//
//  SearchXMLParser.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

@objc class SearchXMLParser: NSObject {
    @objc var serverId = Settings.shared().currentServerId
    
    @objc private(set) var folderArtists = [FolderArtist]()
    @objc private(set) var folderAlbums = [FolderAlbum]()
    @objc private(set) var songs = [NewSong]()
    
    @objc init(data: Data) {
        super.init()
        
        let root = RXMLElement(fromXMLData: data)
        if !root.isValid {
            // TODO: Handle this error in the UI
            DDLogError("[SearchXMLParser] Error parsing search results: \(NSError(ismsCode: Int(ISMSErrorCode_NotXML)))")
        } else {
            if let error = root.child("error"), error.isValid {
                // TODO: Handle this error in the UI
                let code = Int(error.attribute("code") ?? "-1") ?? -1
                let message = error.attribute("message") ?? "no message"
                DDLogError("[SearchXMLParser] Subsonic error: \(NSError(ismsCode: code, message: message))")
            } else {
                if Settings.shared().currentServer.isNewSearchSupported {
                    root.iterate("searchResult2.artist") { element in
                        self.folderArtists.append(FolderArtist(serverId: self.serverId, element: element))
                    }
                    root.iterate("searchResult2.album") { element in
                        self.folderAlbums.append(FolderAlbum(serverId: self.serverId, element: element))
                    }
                    root.iterate("searchResult2.song") { element in
                        let isVideo = element.attribute("isVideo")
                        if isVideo != "true" {
                            let song = NewSong(serverId: self.serverId, element: element)
                            if song.path != "" {
                                self.songs.append(song)
                            }
                        }
                    }
                } else {
                    root.iterate("searchResult.match") { element in
                        let isVideo = element.attribute("isVideo")
                        if isVideo != "true" {
                            let song = NewSong(serverId: self.serverId, element: element)
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
