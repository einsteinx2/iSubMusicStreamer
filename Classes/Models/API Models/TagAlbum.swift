//
//  TagAlbum.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

@objc(ISMSTagAlbum) final class TagAlbum: NSObject, NSCopying {
    @objc(albumId) let id: String
    @objc let name: String
    @objc let coverArtId: String?
    @objc let tagArtistId: String?
    @objc let tagArtistName: String?
    @objc let songCount: Int
    @objc let duration: Int
    @objc let playCount: Int
    @objc let year: Int
    @objc let genre: String?
    
    // TODO: Grab from the database
//    @objc var tagArtist: TagArtist {
//
//    }
    
    @objc init(id: String, name: String, coverArtId: String?, tagArtistId: String?, tagArtistName: String?, songCount: Int, duration: Int, playCount: Int, year: Int, genre: String?) {
        self.id = id
        self.name = name
        self.coverArtId = coverArtId
        self.tagArtistId = tagArtistId
        self.tagArtistName = tagArtistName
        self.songCount = songCount
        self.duration = duration
        self.playCount = playCount
        self.year = year
        self.genre = genre
        super.init()
    }
    
    @objc init(element: RXMLElement) {
        self.id = element.attribute("id")?.clean() ?? ""
        self.name = element.attribute("name")?.clean() ?? ""
        self.coverArtId = element.attribute("coverArt")?.clean()
        self.tagArtistId = element.attribute("artistId")?.clean()
        self.tagArtistName = element.attribute("artist")?.clean()
        self.songCount = Int(element.attribute("songCount") ?? "0") ?? 0
        self.duration = Int(element.attribute("duration") ?? "0") ?? 0
        self.playCount = Int(element.attribute("playCount") ?? "0") ?? 0
        self.year = Int(element.attribute("year") ?? "0") ?? 0
        self.genre = element.attribute("genre")?.clean()
        super.init()
    }
    
    @objc init(result: FMResultSet) {
        self.id = result.string(forColumn: "albumId") ?? ""
        self.name = result.string(forColumn: "name") ?? ""
        self.coverArtId = result.string(forColumn: "coverArtId")
        self.tagArtistId = result.string(forColumn: "artistId")
        self.tagArtistName = result.string(forColumn: "tagArtistName")
        self.songCount = result.long(forColumn: "songCount")
        self.duration = result.long(forColumn: "duration")
        self.playCount = result.long(forColumn: "playCount")
        self.year = result.long(forColumn: "year")
        self.genre = result.string(forColumn: "genre")
        super.init()
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return TagAlbum(id: id, name: name, coverArtId: coverArtId, tagArtistId: tagArtistId, tagArtistName: tagArtistName, songCount: songCount, duration: duration, playCount: playCount, year: year, genre: genre)
    }
    
    override var description: String {
        return "\(super.description): id: \(id), name: \(name), coverArtId: \(coverArtId ?? "nil"), tagArtistId: \(tagArtistId ?? "nil"), tagArtistName: \(tagArtistName ?? "nil"), songCount: \(songCount), duration: \(duration), playCount: \(playCount), year: \(year), genre: \(genre ?? "nil")"
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
    func download() { SongLoader.downloadAll(tagAlbumId: id) }
    func queue() { SongLoader.queueAll(tagAlbumId: id) }
}
