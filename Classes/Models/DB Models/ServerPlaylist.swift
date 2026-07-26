//
//  ServerPlaylist.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

struct ServerPlaylist: Codable, Equatable {
    let serverId: Int
    let id: Int
    var coverArtId: String?
    var name: String
    var comment: String?
    var songCount: Int
    var duration: Int
    var owner: String
    var isPublic: Bool
    var createdDate: Date?
    var changedDate: Date?
    var loadedSongCount: Int
    // TODO: Add allowed users array
    
    var isLoaded: Bool { return songCount == loadedSongCount }
    
    // Reproduces the XML init's defaults exactly (incl. the "nil" sentinel) so DB
    // rows are identical whichever wire format produced them
    init(serverId: Int, dto: PlaylistDTO) {
        self.serverId = serverId
        self.id = Int(dto.id.value) ?? 0
        self.coverArtId = dto.coverArt?.value
        self.name = dto.name ?? "nil"
        self.comment = dto.comment
        self.songCount = dto.songCount ?? 0
        self.duration = dto.duration ?? 0
        self.owner = dto.owner ?? "nil"
        self.isPublic = dto.isPublic ?? false
        self.createdDate = dto.created
        self.changedDate = dto.changed
        self.loadedSongCount = 0
    }

    init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.id = element.attribute("id").intXML
        self.coverArtId = element.attribute("coverArt")
        self.name = element.attribute("name").stringXML
        self.comment = element.attribute("comment")
        self.songCount = element.attribute("songCount").intXML
        self.duration = element.attribute("duration").intXML
        self.owner = element.attribute("owner").stringXML
        self.isPublic = element.attribute("public").boolXML
        self.createdDate = element.attribute("created").dateXMLOptional
        self.changedDate = element.attribute("changed").dateXMLOptional
        self.loadedSongCount = 0
    }
    
    static func ==(lhs: ServerPlaylist, rhs: ServerPlaylist) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.id == rhs.id
    }
}

extension ServerPlaylist: TableCellModel {
    private var store: Store { ModelServices.store }
    
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? {
        var secondaryLabelText = "\(songCount) \("Song".pluralize(amount: songCount))"
        secondaryLabelText += " • \(formatTime(seconds: duration))"
        return secondaryLabelText
    }
    var durationLabelText: String? { formatTime(seconds: duration) }
    var isDownloaded: Bool { false }
    var isDownloadable: Bool { true }
    var isAvailableOffline: Bool { store.isServerPlaylistSongsCached(serverId: serverId, id: id) }
    
    var tagArtistId: String? { nil }
    var tagAlbumId: String? { nil }
    var parentFolderId: String? { nil }
    
    func download() {
        for position in 0..<self.songCount {
            store.song(serverId: serverId, serverPlaylistId: id, position: position)?.download()
        }
    }
    func queue() {
        for position in 0..<self.songCount {
            store.song(serverId: serverId, serverPlaylistId: id, position: position)?.queue()
        }
    }
    func queueNext() {
        var offset = 0
        for position in 0..<self.songCount {
            store.song(serverId: serverId, serverPlaylistId: id, position: position)?.queueNext(offset: offset)
            offset += 1
        }
    }
}
