//
//  TagArtist.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

@objc(ISMSTagArtist) final class TagArtist: NSObject, NSSecureCoding, NSCopying {
    static var supportsSecureCoding = true
    
    @objc(artistId) let id: String
    @objc let name: String
    @objc let coverArtId: String?
    @objc let artistImageUrl: String?
    @objc let albumCount: Int
    
    @objc init(id: String, name: String, coverArtId: String?, artistImageUrl: String?, albumCount: Int) {
        self.id = id
        self.name = name
        self.coverArtId = coverArtId
        self.artistImageUrl = artistImageUrl
        self.albumCount = albumCount
        super.init()
    }
    
    @objc init(attributeDict: [String: String]) {
        self.id = attributeDict["id"] ?? ""
        self.name = attributeDict["name"] ?? ""
        self.coverArtId = attributeDict["coverArt"]
        self.artistImageUrl = attributeDict["artistImageUrl"]
        self.albumCount = Int(attributeDict["albumCount"] ?? "0") ?? 0
        super.init()
    }
    
    @objc init(element: RXMLElement) {
        self.id = element.attribute("id")?.clean() ?? ""
        self.name = element.attribute("name")?.clean() ?? ""
        self.coverArtId = element.attribute("coverArt")?.clean()
        self.artistImageUrl = element.attribute("artistImageUrl")?.clean()
        self.albumCount = Int(element.attribute("albumCount") ?? "0") ?? 0
        super.init()
    }
    
    @objc init(result: FMResultSet) {
        self.id = result.string(forColumn: "id") ?? ""
        self.name = result.string(forColumn: "name") ?? ""
        self.coverArtId = result.string(forColumn: "coverArtId")
        self.artistImageUrl = result.string(forColumn: "artistImageUrl")
        self.albumCount = result.long(forColumn: "albumCount")
    }
    
    @objc init?(coder: NSCoder) {
        self.id = coder.decodeObject(forKey: "id") as? String ?? ""
        self.name = coder.decodeObject(forKey: "name") as? String ?? ""
        self.coverArtId = coder.decodeObject(forKey: "coverArtId") as? String
        self.artistImageUrl = coder.decodeObject(forKey: "artistImageUrl") as? String
        self.albumCount = coder.decodeInteger(forKey: "albumCount")
        super.init()
    }
    
    @objc func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(name, forKey: "name")
        coder.encode(coverArtId, forKey: "coverArtId")
        coder.encode(artistImageUrl, forKey: "artistImageUrl")
        coder.encode(albumCount, forKey: "albumCount")
    }
    
    @objc func copy(with zone: NSZone? = nil) -> Any {
        return TagArtist(id: id, name: name, coverArtId: coverArtId, artistImageUrl: artistImageUrl, albumCount: albumCount)
    }
    
    @objc override var description: String {
        return "\(super.description): id: \(id), name: \(name)"
    }
}

@objc extension TagArtist: TableCellModel {
    var primaryLabelText: String? { return name }
    var secondaryLabelText: String? { return albumCount == 1 ? "1 Album" : "\(albumCount) Albums" }
    var durationLabelText: String? { return nil }
    var isCached: Bool { return false }
    func download() {
//        Database.shared().downloadAllSongs(id, folderArtist: self)
        fatalError("NOT IMPLEMENTED YET")
    }
    func queue() {
//        Database.shared().queueAllSongs(id, folderArtist: self)
        fatalError("NOT IMPLEMENTED YET")
    }
}
