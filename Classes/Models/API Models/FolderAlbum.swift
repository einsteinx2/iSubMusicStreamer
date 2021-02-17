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
    let id: Int
    let name: String
    let coverArtId: String?
    let parentFolderId: Int?
    let tagArtistName: String?
    let tagAlbumName: String?
    let playCount: Int
    let year: Int?
    let genre: String?
    let userRating: Int?
    let averageRating: Double?
    let createdDate: Date
    let starredDate: Date?
    
    init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.id = element.attribute("id").intXML
        self.name = element.attribute("title").stringXML
        self.coverArtId = element.attribute("coverArt").stringXMLOptional
        self.parentFolderId = element.attribute("parent").intXML
        self.tagArtistName = element.attribute("artist").stringXMLOptional
        self.tagAlbumName = element.attribute("artist").stringXMLOptional
        self.playCount = element.attribute("playCount").intXML
        self.year = element.attribute("year").intXMLOptional
        self.genre = element.attribute("genre")
        self.userRating = element.attribute("userRating").intXMLOptional
        self.averageRating = element.attribute("averageRating").doubleXMLOptional
        self.createdDate = element.attribute("created").dateXML
        self.starredDate = element.attribute("starred").dateXMLOptional
    }
    
    static func ==(lhs: FolderAlbum, rhs: FolderAlbum) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.id == rhs.id
    }
}

extension FolderAlbum: TableCellModel {
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? { nil }
    var durationLabelText: String? { nil }
    var isDownloaded: Bool { false }
    var isDownloadable: Bool { true }
    
    var tagArtistId: Int? { nil }
    var tagAlbumId: Int? { nil }
    
    func download() { SongsHelper.downloadAll(serverId: serverId, folderId: id) }
    func queue() { SongsHelper.queueAll(serverId: serverId, folderId: id) }
    func queueNext() {
        // TODO: implement this
        fatalError("implement this")
    }
}
