//
//  TagAlbum.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

struct TagAlbum: Codable, Equatable {
    let serverId: Int
    let id: Int
    let name: String
    let coverArtId: String?
    let tagArtistId: Int?
    let tagArtistName: String?
    let songCount: Int
    let duration: Int
    let playCount: Int
    let year: Int
    let genre: String?
    let createdDate: Date
    let starredDate: Date?
    
    init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.id = element.attribute("id").intXML
        self.name = element.attribute("name").stringXML
        self.coverArtId = element.attribute("coverArt").stringXMLOptional
        self.tagArtistId = element.attribute("artistId").intXMLOptional
        self.tagArtistName = element.attribute("artist").stringXMLOptional
        self.songCount = element.attribute("songCount").intXML
        self.duration = element.attribute("duration").intXML
        self.playCount = element.attribute("playCount").intXML
        self.year = element.attribute("year").intXML
        self.genre = element.attribute("genre").stringXML
        self.createdDate = element.attribute("created").dateXML
        self.starredDate = element.attribute("starred").dateXMLOptional
    }
    
    static func ==(lhs: TagAlbum, rhs: TagAlbum) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.id == rhs.id
    }
}

extension TagAlbum: TableCellModel {
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? {
        var textParts = [String]()
        if year > 0 { textParts.append(String(year)) }
        textParts.append("\(songCount) \("Song".pluralize(amount: songCount))")
        textParts.append(formatTime(seconds: duration))
        
        var text = textParts[0]
        for i in 1..<textParts.count {
            text += " • " + textParts[i]
        }
        return text
    }
    var durationLabelText: String? { nil }
    
    var tagAlbumId: Int? { nil }
    var parentFolderId: Int? { nil }
    var isDownloaded: Bool { false }
    var isDownloadable: Bool { true }
    
    func download() { SongsHelper.downloadAll(serverId: serverId, tagAlbumId: id) }
    func queue() { SongsHelper.queueAll(serverId: serverId, tagAlbumId: id) }
    func queueNext() { SongsHelper.queueAllNext(serverId: serverId, tagAlbumId: id) }
}
