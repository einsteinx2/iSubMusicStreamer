//
//  FolderAlbum.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

@objc(ISMSFolderAlbum) class FolderAlbum: NSObject, NSCopying {
    @objc(folderId) let id: String
    @objc let title: String
    @objc let coverArtId: String?
    @objc let parentFolderId: String
    @objc let tagArtistName: String?
    @objc let tagAlbumName: String?
    @objc let playCount: Int
    @objc let year: Int
    
    @objc init(id: String, title: String, coverArtId: String?, parentFolderId: String, tagArtistName: String?, tagAlbumName: String?, playCount: Int, year: Int) {
        self.id = id
        self.title = title
        self.coverArtId = coverArtId
        self.parentFolderId = parentFolderId
        self.tagArtistName = tagArtistName
        self.tagAlbumName = tagAlbumName
        self.playCount = playCount
        self.year = year
        super.init()
    }
    
    @objc init(element: RXMLElement) {
        self.id = element.attribute("id")?.clean() ?? ""
        self.title = element.attribute("title")?.clean() ?? ""
        self.coverArtId = element.attribute("coverArt")?.clean()
        self.parentFolderId = element.attribute("parent")?.clean() ?? ""
        self.tagArtistName = element.attribute("artist")?.clean()
        self.tagAlbumName = element.attribute("artist")?.clean()
        self.playCount = Int(element.attribute("playCount") ?? "0") ?? 0
        self.year = Int(element.attribute("year") ?? "0") ?? 0
        super.init()
    }
    
    @objc init(result: FMResultSet) {
        self.id = result.string(forColumn: "subfolderId") ?? ""
        self.title = result.string(forColumn: "title") ?? ""
        self.coverArtId = result.string(forColumn: "coverArtId")
        self.parentFolderId = result.string(forColumn: "folderId") ?? ""
        self.tagArtistName = result.string(forColumn: "tagArtistName")
        self.tagAlbumName = result.string(forColumn: "tagAlbumName")
        self.playCount = result.long(forColumn: "playCount")
        self.year = result.long(forColumn: "year")
        super.init()
    }
    
    @objc func copy(with zone: NSZone? = nil) -> Any {
        return FolderAlbum(id: id, title: title, coverArtId: coverArtId, parentFolderId: parentFolderId, tagArtistName: tagArtistName, tagAlbumName: tagAlbumName, playCount: playCount, year: year)
    }
    
    @objc override var description: String {
        return "\(super.description): id: \(id), title: \(title), coverArtId: \(coverArtId ?? "nil"), parentFolderId: \(parentFolderId), tagArtistName: \(tagArtistName ?? "nil"), tagAlbumName: \(tagAlbumName ?? "nil"), playCount: \(playCount), year: \(year)"
    }
}

@objc extension FolderAlbum: TableCellModel {
    var primaryLabelText: String? { return title }
    var secondaryLabelText: String? { return nil }
    var durationLabelText: String? { return nil }
    var isCached: Bool { return false }
    func download() { SongLoader.downloadAll(folderId: id) }
    func queue() { SongLoader.queueAll(folderId: id) }
}
