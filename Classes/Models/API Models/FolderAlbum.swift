//
//  FolderAlbum.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

struct FolderAlbum: Codable, Equatable {
    let serverId: Int
    let id: String
    let name: String
    let coverArtId: String?
    let parentFolderId: String?
    let tagArtistName: String?
    let tagAlbumName: String?
    let playCount: Int
    let year: Int?
    let genre: String?
    let userRating: Int?
    let averageRating: Double?
    let createdDate: Date
    let starredDate: Date?
    
    // Reproduces the XML init's defaults exactly (incl. the "nil" sentinel) so DB
    // rows are identical whichever wire format produced them
    init(serverId: Int, dto: ChildDTO) {
        self.serverId = serverId
        self.id = dto.id.value
        self.name = dto.title ?? "nil"
        self.coverArtId = dto.coverArt?.value
        self.parentFolderId = dto.parent?.value
        self.tagArtistName = dto.artist
        self.tagAlbumName = dto.album
        self.playCount = dto.playCount ?? 0
        self.year = dto.year
        self.genre = dto.genre
        self.userRating = dto.userRating
        self.averageRating = dto.averageRating
        self.createdDate = dto.created ?? .distantPast
        self.starredDate = dto.starred
    }

    static func ==(lhs: FolderAlbum, rhs: FolderAlbum) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.id == rhs.id
    }
}

extension FolderAlbum: TableCellModel {
    private var store: Store { ModelServices.store }
    
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? { nil }
    var durationLabelText: String? { nil }
    var isDownloaded: Bool { false }
    var isDownloadable: Bool { true }
    var isAvailableOffline: Bool { store.isFolderMetadataCached(serverId: serverId, parentFolderId: id) }
    
    var tagArtistId: String? { nil }
    var tagAlbumId: String? { nil }
    
    func download() { AsyncSongsHelper.downloadAll(serverId: serverId, folderId: id) }
    func queue() { AsyncSongsHelper.queueAll(serverId: serverId, folderId: id) }
    func queueNext() { AsyncSongsHelper.queueAllNext(serverId: serverId, folderId: id) }
}
