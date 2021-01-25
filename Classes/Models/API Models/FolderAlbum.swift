//
//  FolderAlbum.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

struct FolderAlbum: Codable, Equatable {
    let serverId: Int
    let id: Int
    let name: String
    let coverArtId: String?
    let parentFolderId: Int
    let tagArtistName: String?
    let tagAlbumName: String?
    let playCount: Int
    let year: Int
    
    init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.id = element.attribute("id").intXML
        self.name = element.attribute("title").stringXML
        self.coverArtId = element.attribute("coverArt").stringXMLOptional
        self.parentFolderId = element.attribute("parent").intXML
        self.tagArtistName = element.attribute("artist").stringXMLOptional
        self.tagAlbumName = element.attribute("artist").stringXMLOptional
        self.playCount = element.attribute("playCount").intXML
        self.year = element.attribute("year").intXML
    }
    
    static func ==(lhs: FolderAlbum, rhs: FolderAlbum) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.id == rhs.id
    }
}

extension FolderAlbum: TableCellModel {
    var primaryLabelText: String? { return name }
    var secondaryLabelText: String? { return nil }
    var durationLabelText: String? { return nil }
    var isCached: Bool { return false }
    func download() { SongLoader.downloadAll(serverId: serverId, folderId: id) }
    func queue() { SongLoader.queueAll(serverId: serverId, folderId: id) }
}
