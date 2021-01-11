//
//  TagAlbum.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

@objc(ISMSTagAlbum) final class TagAlbum: NSObject, NSCopying, Codable {
    @objc let serverId: Int
    @objc(albumId) let id: Int
    @objc let name: String
    @objc let coverArtId: String?
    @objc let tagArtistId: String?
    @objc let tagArtistName: String?
    @objc let songCount: Int
    @objc let duration: Int
    @objc let playCount: Int
    @objc let year: Int
    @objc let genre: String?
    
    @objc(initWithServerId:albumId:name:coverArtId:tagArtistId:tagArtistName:songCount:duration:playCount:year:genre:)
    init(serverId: Int, id: Int, name: String, coverArtId: String?, tagArtistId: String?, tagArtistName: String?, songCount: Int, duration: Int, playCount: Int, year: Int, genre: String?) {
        self.serverId = serverId
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
    
    @objc init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.id = element.attribute("id").intXML
        self.name = element.attribute("name").stringXML
        self.coverArtId = element.attribute("coverArt").stringXMLOptional
        self.tagArtistId = element.attribute("artistId").stringXMLOptional
        self.tagArtistName = element.attribute("artist").stringXMLOptional
        self.songCount = element.attribute("songCount").intXML
        self.duration = element.attribute("duration").intXML
        self.playCount = element.attribute("playCount").intXML
        self.year = element.attribute("year").intXML
        self.genre = element.attribute("genre").stringXML
        super.init()
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        TagAlbum(serverId: serverId, id: id, name: name, coverArtId: coverArtId, tagArtistId: tagArtistId, tagArtistName: tagArtistName, songCount: songCount, duration: duration, playCount: playCount, year: year, genre: genre)
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? TagAlbum {
            return self === object || (serverId == object.serverId && id == object.id)
        }
        return false
    }
    
    override var description: String {
        "\(super.description): serverId: \(serverId), id: \(id), name: \(name), coverArtId: \(coverArtId ?? "nil"), tagArtistId: \(tagArtistId ?? "nil"), tagArtistName: \(tagArtistName ?? "nil"), songCount: \(songCount), duration: \(duration), playCount: \(playCount), year: \(year), genre: \(genre ?? "nil")"
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
