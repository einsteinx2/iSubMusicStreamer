//
//  SearchXMLParser.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

@objc class SearchXMLParser: NSObject, XMLParserDelegate {
    @objc private(set) var folderArtists = [FolderArtist]()
    @objc private(set) var folderAlbums = [FolderAlbum]()
    @objc private(set) var songs = [Song]()
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "match" || elementName == "song" {
            if attributeDict["isVideo"] != "true" {
                let song = Song(attributeDict: attributeDict)
                if song.path != nil {
                    songs.append(song)
                }
            }
        } else if elementName == "album" {
            folderAlbums.append(FolderAlbum(attributeDict: attributeDict))
        } else if elementName == "artist" {
            folderArtists.append(FolderArtist(attributeDict: attributeDict))
        }
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // TODO: Handle error
    }
}
