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
    let id: String
    let name: String
    let coverArtId: String?
    let tagArtistId: String?
    let tagArtistName: String?
    let songCount: Int
    let duration: Int
    let playCount: Int
    let year: Int
    let genre: String?
    let createdDate: Date
    let starredDate: Date?
    
    // Reproduces the XML init's defaults exactly (incl. the "nil" sentinel) so DB
    // rows are identical whichever wire format produced them
    init(serverId: Int, dto: AlbumID3DTO) {
        self.serverId = serverId
        self.id = dto.id.value
        self.name = dto.name ?? "nil"
        self.coverArtId = dto.coverArt?.value
        self.tagArtistId = dto.artistId?.value
        self.tagArtistName = dto.artist
        self.songCount = dto.songCount ?? 0
        self.duration = dto.duration ?? 0
        self.playCount = dto.playCount ?? 0
        self.year = dto.year ?? 0
        self.genre = dto.genre ?? "nil"
        self.createdDate = dto.created ?? .distantPast
        self.starredDate = dto.starred
    }

    static func ==(lhs: TagAlbum, rhs: TagAlbum) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.id == rhs.id
    }
}

extension TagAlbum: TableCellModel {
    private var store: Store { ModelServices.store }
    
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
    
    var tagAlbumId: String? { nil }
    var parentFolderId: String? { nil }
    var isDownloaded: Bool { false }
    var isDownloadable: Bool { true }
    var isAvailableOffline: Bool { store.isTagAlbumSongsCached(serverId: serverId, id: id) }
    
    func download() { AsyncSongsHelper.downloadAll(serverId: serverId, tagAlbumId: id) }
    func queue() { AsyncSongsHelper.queueAll(serverId: serverId, tagAlbumId: id) }
    func queueNext() { AsyncSongsHelper.queueAllNext(serverId: serverId, tagAlbumId: id) }
}
