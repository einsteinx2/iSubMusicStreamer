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
    @objc private(set) var folderArtists = [FolderArtist]()
    @objc private(set) var folderAlbums = [FolderAlbum]()
    @objc private(set) var songs = [Song]()
    
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
                if Settings.shared().isNewSearchAPI {
                    root.iterate("searchResult2.artist") { element in
                        self.folderArtists.append(FolderArtist(element: element))
                    }
                    root.iterate("searchResult2.album") { element in
                        self.folderAlbums.append(FolderAlbum(element: element))
                    }
                    root.iterate("searchResult2.song") { element in
                        let isVideo = element.attribute("isVideo")
                        if isVideo != "true" {
                            let song = Song(rxmlElement: element)
                            if song.path != nil {
                                self.songs.append(song)
                            }
                        }
                    }
                } else {
                    root.iterate("searchResult.match") { element in
                        let isVideo = element.attribute("isVideo")
                        if isVideo != "true" {
                            let song = Song(rxmlElement: element)
                            if song.path != nil {
                                self.songs.append(song)
                            }
                        }
                    }
                }
            }
        }
    }
}
