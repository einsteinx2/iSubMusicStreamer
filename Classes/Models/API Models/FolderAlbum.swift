//
//  FolderAlbum.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

@objc(ISMSFolderAlbum) class FolderAlbum: NSObject, NSCopying, Codable {
    @objc let serverId: Int
    @objc(folderId) let id: Int
    @objc let name: String
    @objc let coverArtId: String?
    @objc let parentFolderId: Int
    @objc let tagArtistName: String?
    @objc let tagAlbumName: String?
    @objc let playCount: Int
    @objc let year: Int
    
    @objc(initWithServerId:folderId:name:coverArtId:parentFolderId:tagArtistName:tagAlbumName:playCount:year:)
    init(serverId: Int, id: Int, name: String, coverArtId: String?, parentFolderId: Int, tagArtistName: String?, tagAlbumName: String?, playCount: Int, year: Int) {
        self.serverId = serverId
        self.id = id
        self.name = name
        self.coverArtId = coverArtId
        self.parentFolderId = parentFolderId
        self.tagArtistName = tagArtistName
        self.tagAlbumName = tagAlbumName
        self.playCount = playCount
        self.year = year
        super.init()
    }
    
    @objc init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.id = element.attribute("id").intXML
        self.name = element.attribute("title").stringXML
        self.coverArtId = element.attribute("coverArt").stringXMLOptional
        self.parentFolderId = element.attribute("parent").intXML
        self.tagArtistName = element.attribute("artist").stringXMLOptional
        self.tagAlbumName = element.attribute("artist").stringXMLOptional
        self.playCount = element.attribute("playCount").intXML
        self.year = element.attribute("year").intXML
        super.init()
    }
    
    @objc func copy(with zone: NSZone? = nil) -> Any {
        return FolderAlbum(serverId: serverId, id: id, name: name, coverArtId: coverArtId, parentFolderId: parentFolderId, tagArtistName: tagArtistName, tagAlbumName: tagAlbumName, playCount: playCount, year: year)
    }
    
    @objc override var description: String {
        return "\(super.description): serverId: \(serverId), id: \(id), name: \(name), coverArtId: \(coverArtId ?? "nil"), parentFolderId: \(parentFolderId), tagArtistName: \(tagArtistName ?? "nil"), tagAlbumName: \(tagAlbumName ?? "nil"), playCount: \(playCount), year: \(year)"
    }
}

@objc extension FolderAlbum: TableCellModel {
    var primaryLabelText: String? { return name }
    var secondaryLabelText: String? { return nil }
    var durationLabelText: String? { return nil }
    var isCached: Bool { return false }
    func download() { SongLoader.downloadAll(folderId: id) }
    func queue() { SongLoader.queueAll(folderId: id) }
}
