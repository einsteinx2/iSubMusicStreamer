//
//  ServerPlaylist.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

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
    private var store: Store { Resolver.resolve() }
    
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? {
        var secondaryLabelText = (songCount == 1 ? "1 song" : "\(songCount) songs")
        secondaryLabelText += " • \(formatTime(seconds: duration))"
        return secondaryLabelText
    }
    var durationLabelText: String? { formatTime(seconds: duration) }
    var isDownloaded: Bool { false }
    var isDownloadable: Bool { true }
    
    var tagArtistId: Int? { nil }
    var tagAlbumId: Int? { nil }
    var parentFolderId: Int? { nil }
    
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
        // TODO: implement this
        fatalError("implement this")
    }
}
