//
//  TagAlbum.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

@objc(ISMSTagAlbum) final class TagAlbum: NSObject, NSSecureCoding, NSCopying {
    static let supportsSecureCoding = true
    
    @objc(albumId) let id: String
    @objc let name: String
    @objc let coverArtId: String?
    @objc let tagArtistId: String
    @objc let tagArtistName: String
    @objc let songCount: Int
    @objc let duration: Int
    @objc let playCount: Int
    @objc let year: Int
    
    // TODO: Grab from the database
//    @objc var tagArtist: TagArtist {
//
//    }
    
    @objc init(id: String, name: String, coverArtId: String?, tagArtistId: String, tagArtistName: String, songCount: Int, duration: Int, playCount: Int, year: Int) {
        self.id = id
        self.name = name
        self.coverArtId = coverArtId
        self.tagArtistId = tagArtistId
        self.tagArtistName = tagArtistName
        self.songCount = songCount
        self.duration = duration
        self.playCount = playCount
        self.year = year
        super.init()
    }
    
    @objc init(attributeDict: [String: String]) {
        self.id = attributeDict["id"]?.clean() ?? ""
        self.name = attributeDict["name"]?.clean() ?? ""
        self.coverArtId = attributeDict["coverArt"]?.clean()
        self.tagArtistId = attributeDict["artistId"]?.clean() ?? ""
        self.tagArtistName = attributeDict["artist"]?.clean() ?? ""
        self.songCount = Int(attributeDict["songCount"] ?? "0") ?? 0
        self.duration = Int(attributeDict["duration"] ?? "0") ?? 0
        self.playCount = Int(attributeDict["playCount"] ?? "0") ?? 0
        self.year = Int(attributeDict["year"] ?? "0") ?? 0
        super.init()
    }
    
    @objc init(element: RXMLElement) {
        self.id = element.attribute("id")?.clean() ?? ""
        self.name = element.attribute("name")?.clean() ?? ""
        self.coverArtId = element.attribute("coverArt")?.clean()
        self.tagArtistId = element.attribute("artistId")?.clean() ?? ""
        self.tagArtistName = element.attribute("artist")?.clean() ?? ""
        self.songCount = Int(element.attribute("songCount") ?? "0") ?? 0
        self.duration = Int(element.attribute("duration") ?? "0") ?? 0
        self.playCount = Int(element.attribute("playCount") ?? "0") ?? 0
        self.year = Int(element.attribute("year") ?? "0") ?? 0
        super.init()
    }
    
    @objc init(result: FMResultSet) {
        self.id = result.string(forColumn: "albumId") ?? ""
        self.name = result.string(forColumn: "name") ?? ""
        self.coverArtId = result.string(forColumn: "coverArtId")
        self.tagArtistId = result.string(forColumn: "tagArtistId") ?? ""
        self.tagArtistName = result.string(forColumn: "tagArtistName") ?? ""
        self.songCount = result.long(forColumn: "songCount")
        self.duration = result.long(forColumn: "duration")
        self.playCount = result.long(forColumn: "playCount")
        self.year = result.long(forColumn: "year")
        super.init()
    }
    
    init?(coder: NSCoder) {
        self.id = coder.decodeObject(forKey: "id") as? String ?? ""
        self.name = coder.decodeObject(forKey: "name") as? String ?? ""
        self.coverArtId = coder.decodeObject(forKey: "coverArtId") as? String
        self.tagArtistId = coder.decodeObject(forKey: "tagArtistId") as? String ?? ""
        self.tagArtistName = coder.decodeObject(forKey: "tagArtistName") as? String ?? ""
        self.songCount = coder.decodeInteger(forKey: "songCount")
        self.duration = coder.decodeInteger(forKey: "duration")
        self.playCount = coder.decodeInteger(forKey: "playCount")
        self.year = coder.decodeInteger(forKey: "year")
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(id, forKey: "id")
        coder.encode(name, forKey: "name")
        coder.encode(coverArtId, forKey: "coverArtId")
        coder.encode(tagArtistId, forKey: "tagArtistId")
        coder.encode(tagArtistName, forKey: "tagArtistName")
        coder.encode(songCount, forKey: "songCount")
        coder.encode(duration, forKey: "duration")
        coder.encode(playCount, forKey: "playCount")
        coder.encode(year, forKey: "year")
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return TagAlbum(id: id, name: name, coverArtId: coverArtId, tagArtistId: tagArtistId, tagArtistName: tagArtistName, songCount: songCount, duration: duration, playCount: playCount, year: year)
    }
}

@objc extension TagAlbum: TableCellModel {
    var primaryLabelText: String? { return name }
    var secondaryLabelText: String? {
        var textParts = [String]()
        if year > 0 { textParts.append(String(year)) }
        textParts.append(songCount == 1 ? "1 Song" : "\(songCount) Songs")
        textParts.append(NSString.formatTime(Double(duration)))
        
        var text = textParts[0]
        for i in 1..<textParts.count {
            text += " • " + textParts[i]
        }
        return text
    }
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
