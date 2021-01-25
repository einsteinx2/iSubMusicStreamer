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
    
    init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.id =  element.attribute("id").intXML
        self.name = element.attribute("name").stringXML
    }
    
    static func ==(lhs: FolderArtist, rhs: FolderArtist) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.id == rhs.id
    }
}

extension FolderArtist: TableCellModel {
    var primaryLabelText: String? { return name }
    var secondaryLabelText: String? { return nil }
    var durationLabelText: String? { return nil }
    var coverArtId: String? { return nil }
    var isCached: Bool { return false }
    func download() { SongLoader.downloadAll(serverId: serverId, folderId: id) }
    func queue() { SongLoader.queueAll(serverId: serverId, folderId: id) }
}

extension FolderArtist: Artist {
    var artistImageUrl: String? { nil }
    var albumCount: Int { -1 }
}
