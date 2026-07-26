//
//  RootFolder.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation

struct FolderArtist: Codable, Equatable {
    let serverId: Int
    let id: String
    let name: String
    let userRating: Int?
    let averageRating: Double?
    let starredDate: Date?
    
    // Reproduces the XML init's defaults exactly (incl. the "nil" sentinel) so DB
    // rows are identical whichever wire format produced them
    init(serverId: Int, dto: FolderArtistDTO) {
        self.serverId = serverId
        self.id = dto.id.value
        self.name = dto.name ?? "nil"
        self.userRating = dto.userRating
        self.averageRating = dto.averageRating
        self.starredDate = dto.starred
    }

    static func ==(lhs: FolderArtist, rhs: FolderArtist) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.id == rhs.id
    }
}

extension FolderArtist: TableCellModel {
    private var store: Store { ModelServices.store }
    
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? { nil }
    var durationLabelText: String? { nil }
    var coverArtId: String? { nil }
    var isDownloaded: Bool { false }
    var isDownloadable: Bool { true }
    var isAvailableOffline: Bool { store.isFolderMetadataCached(serverId: serverId, parentFolderId: id) }
    
    var tagArtistId: String? { nil }
    var tagAlbumId: String? { nil }
    var parentFolderId: String? { nil }
    
    func download() { AsyncSongsHelper.downloadAll(serverId: serverId, folderId: id) }
    func queue() { AsyncSongsHelper.queueAll(serverId: serverId, folderId: id) }
    func queueNext() { AsyncSongsHelper.queueAllNext(serverId: serverId, folderId: id) }
}

extension FolderArtist: Artist {
    var artistImageUrl: String? { nil }
    var albumCount: Int { -1 }
}
