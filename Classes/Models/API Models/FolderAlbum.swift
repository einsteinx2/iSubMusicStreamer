//
//  FolderAlbum.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

@objc(ISMSFolderAlbum) class FolderAlbum: NSObject, NSSecureCoding, NSCopying {
    static var supportsSecureCoding = true

    @objc(folderId) let id: String
    @objc let title: String
    @objc let coverArtId: String?
    @objc let folderArtistId: String
    @objc let folderArtistName: String
    
    @objc var folderArtist: FolderArtist {
        return FolderArtist(id: folderArtistId, name: folderArtistName)
    }
    
    @objc init(id: String, title: String, coverArtId: String?, folderArtistId: String, folderArtistName: String) {
        self.id = id
        self.title = title
        self.coverArtId = coverArtId
        self.folderArtistId = folderArtistId
        self.folderArtistName = folderArtistName
        super.init()
    }
    
    @objc init(attributeDict: [String: String]) {
        self.id = attributeDict["id"]?.clean() ?? ""
        self.title = attributeDict["title"]?.clean() ?? ""
        self.coverArtId = attributeDict["coverArt"]?.clean()
        self.folderArtistId = attributeDict["parent"]?.clean() ?? ""
        self.folderArtistName = attributeDict["artist"]?.clean() ?? ""
        super.init()
    }
    
    @objc init(element: RXMLElement) {
        self.id = element.attribute("id")?.clean() ?? ""
        self.title = element.attribute("title")?.clean() ?? ""
        self.coverArtId = element.attribute("coverArt")?.clean()
        self.folderArtistId = element.attribute("parent")?.clean() ?? ""
        self.folderArtistName = element.attribute("artist")?.clean() ?? ""
        super.init()
    }
    
    @objc init(element: RXMLElement, folderArtist: FolderArtist) {
        self.id = element.attribute("id")?.clean() ?? ""
        self.title = element.attribute("title")?.clean() ?? ""
        self.coverArtId = element.attribute("coverArt")?.clean()
        self.folderArtistId = folderArtist.id
        self.folderArtistName = folderArtist.name
        super.init()
    }
    
    @objc init(result: FMResultSet) {
        self.id = result.string(forColumn: "albumId") ?? ""
        self.title = result.string(forColumn: "title") ?? ""
        self.coverArtId = result.string(forColumn: "coverArtId")
        self.folderArtistId = result.string(forColumn: "artistId") ?? ""
        self.folderArtistName = result.string(forColumn: "artistName") ?? ""
        super.init()
    }
    
    @objc required init?(coder: NSCoder) {
        self.id = coder.decodeObject(forKey: "id") as? String ?? ""
        self.title = coder.decodeObject(forKey: "title") as? String ?? ""
        self.coverArtId = coder.decodeObject(forKey: "coverArtId") as? String
        self.folderArtistId = coder.decodeObject(forKey: "folderArtistId") as? String ?? ""
        self.folderArtistName = coder.decodeObject(forKey: "folderArtistName") as? String ?? ""
        super.init()
    }
    
    @objc func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(title, forKey: "title")
        coder.encode(coverArtId, forKey: "coverArtId")
        coder.encode(folderArtistId, forKey: "folderArtistId")
        coder.encode(folderArtistName, forKey: "folderArtistName")
    }
    
    @objc func copy(with zone: NSZone? = nil) -> Any {
        return FolderAlbum(id: id, title: title, coverArtId: coverArtId, folderArtistId: folderArtistId, folderArtistName: folderArtistName)
    }
    
    @objc override var description: String {
        return "\(super.description): id: \(id) title: \(title) coverArtId: \(coverArtId ?? "") folderArtistId: \(folderArtistId) folderArtistName: \(folderArtistName)"
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
