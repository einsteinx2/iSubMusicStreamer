//
//  TagArtist.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

struct TagArtist: Artist, Codable, Equatable {
    let serverId: Int
    let id: String
    let name: String
    let coverArtId: String?
    let artistImageUrl: String?
    let albumCount: Int
    let starredDate: Date?
    
    // Reproduces the XML init's defaults exactly (incl. the "nil" sentinel) so DB
    // rows are identical whichever wire format produced them
    init(serverId: Int, dto: ArtistID3DTO) {
        self.serverId = serverId
        self.id = dto.id.value
        self.name = dto.name ?? "nil"
        self.coverArtId = dto.coverArt?.value
        self.artistImageUrl = dto.artistImageUrl
        self.albumCount = dto.albumCount ?? 0
        self.starredDate = dto.starred
    }

    static func ==(lhs: TagArtist, rhs: TagArtist) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.id == rhs.id
    }
}

extension TagArtist: TableCellModel {
    private var store: Store { ModelServices.store }
    
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? { "\(albumCount) \("Album".pluralize(amount: albumCount))" }
    var durationLabelText: String? { nil }
    var isDownloaded: Bool { false }
    var isDownloadable: Bool { true }
    var isAvailableOffline: Bool { store.isTagArtistAlbumsCached(serverId: serverId, id: id) }
    
    var tagArtistId: String? { nil }
    var tagAlbumId: String? { nil }
    var parentFolderId: String? { nil }
    
    func download() { AsyncSongsHelper.downloadAll(serverId: serverId, tagArtistId: id) }
    func queue() { AsyncSongsHelper.queueAll(serverId: serverId, tagArtistId: id) }
    func queueNext() { AsyncSongsHelper.queueAllNext(serverId: serverId, tagArtistId: id) }
}
