//
//  FolderAlbum.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

@objc(ISMSFolderAlbum) class FolderAlbum: NSObject, NSCopying {
    static var supportsSecureCoding = true

    @objc(folderId) let id: String
    @objc let title: String
    @objc let coverArtId: String?
    @objc let parentFolderId: String
    @objc let folderArtistId: String
    @objc let folderArtistName: String
    @objc let tagAlbumName: String?
    @objc let playCount: Int
    @objc let year: Int
    
    @objc var folderArtist: FolderArtist {
        return FolderArtist(id: folderArtistId, name: folderArtistName)
    }
    
    @objc init(id: String, title: String, coverArtId: String?, parentFolderId: String, folderArtistId: String, folderArtistName: String, tagAlbumName: String?, playCount: Int, year: Int) {
        self.id = id
        self.title = title
        self.coverArtId = coverArtId
        self.parentFolderId = parentFolderId
        self.folderArtistId = folderArtistId
        self.folderArtistName = folderArtistName
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
        // TODO: Figure out what to do with this artist ID
        // TODO: Maybe make this optional
        self.folderArtistId = element.attribute("parent")?.clean() ?? ""
        // TODO: Maybe make this optional
        self.folderArtistName = element.attribute("artist")?.clean() ?? ""
        self.tagAlbumName = element.attribute("artist")?.clean()
        self.playCount = Int(element.attribute("playCount") ?? "0") ?? 0
        self.year = Int(element.attribute("year") ?? "0") ?? 0
        super.init()
    }
    
    @objc init(element: RXMLElement, folderArtist: FolderArtist) {
        self.id = element.attribute("id")?.clean() ?? ""
        self.title = element.attribute("title")?.clean() ?? ""
        self.coverArtId = element.attribute("coverArt")?.clean()
        self.parentFolderId = element.attribute("parent")?.clean() ?? ""
        self.folderArtistId = folderArtist.id
        self.folderArtistName = folderArtist.name
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
        self.folderArtistId = result.string(forColumn: "folderArtistId") ?? ""
        self.folderArtistName = result.string(forColumn: "folderArtistName") ?? ""
        self.tagAlbumName = result.string(forColumn: "tagAlbumName")
        self.playCount = result.long(forColumn: "playCount")
        self.year = result.long(forColumn: "year")
        super.init()
    }
    
    @objc func copy(with zone: NSZone? = nil) -> Any {
        return FolderAlbum(id: id, title: title, coverArtId: coverArtId, parentFolderId: parentFolderId, folderArtistId: folderArtistId, folderArtistName: folderArtistName, tagAlbumName: tagAlbumName, playCount: playCount, year: year)
    }
    
    @objc override var description: String {
        return "\(super.description): id: \(id), title: \(title), coverArtId: \(coverArtId ?? "nil"), parentFolderId: \(parentFolderId), folderArtistId: \(folderArtistId), folderArtistName: \(folderArtistName), tagAlbumName: \(tagAlbumName ?? "nil"), playCount: \(playCount), year: \(year)"
    }
}

@objc extension FolderAlbum: TableCellModel {
    var primaryLabelText: String? { return title }
    var secondaryLabelText: String? { return folderArtistName }
    var durationLabelText: String? { return nil }
    var isCached: Bool { return false }
    func download() { Database.shared().downloadAllSongs(id, folderArtist: folderArtist) }
    func queue() { Database.shared().queueAllSongs(id, folderArtist: folderArtist) }
}
