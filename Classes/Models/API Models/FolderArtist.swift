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
    let id: Int
    let name: String
    let userRating: Int?
    let averageRating: Double?
    let starredDate: Date?
    
    init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.id =  element.attribute("id").intXML
        self.name = element.attribute("name").stringXML
        self.userRating = element.attribute("userRating").intXMLOptional
        self.averageRating = element.attribute("averageRating").doubleXMLOptional
        self.starredDate = element.attribute("starred").dateXMLOptional
    }
    
    static func ==(lhs: FolderArtist, rhs: FolderArtist) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.id == rhs.id
    }
}

extension FolderArtist: TableCellModel {
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? { nil }
    var durationLabelText: String? { nil }
    var coverArtId: String? { nil }
    var isDownloaded: Bool { false }
    var isDownloadable: Bool { true }
    
    var tagArtistId: Int? { nil }
    var tagAlbumId: Int? { nil }
    var parentFolderId: Int? { nil }
    
    func download() { SongsHelper.downloadAll(serverId: serverId, folderId: id) }
    func queue() { SongsHelper.queueAll(serverId: serverId, folderId: id) }
    func queueNext() { SongsHelper.queueAllNext(serverId: serverId, folderId: id) }
}

extension FolderArtist: Artist {
    var artistImageUrl: String? { nil }
    var albumCount: Int { -1 }
}
