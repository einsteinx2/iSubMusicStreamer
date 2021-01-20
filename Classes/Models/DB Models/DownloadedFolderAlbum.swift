//
//  DownloadedFolderAlbum.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class DownloadedFolderAlbum: Codable, CustomStringConvertible {
    let serverId: Int
    let level: Int
    let name: String
    let coverArtId: String?
    
    init(serverId: Int, level: Int, name: String, coverArtId: String?) {
        self.serverId = serverId
        self.level = level
        self.name = name
        self.coverArtId = coverArtId
    }
    
    static func ==(lhs: DownloadedFolderAlbum, rhs: DownloadedFolderAlbum) -> Bool {
        return lhs === rhs || (lhs.serverId == rhs.serverId && lhs.level == rhs.level && lhs.name == rhs.name)
    }
}

extension DownloadedFolderAlbum: TableCellModel {
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? {
        // TODO: implement this using number of songs downloaded
        nil
    }
    var durationLabelText: String? { nil }
    var isCached: Bool { true }
    func download() {
        let store: Store = Resolver.resolve()
        let songs = store.songsRecursive(serverId: serverId, level: level, parentPathComponent: name)
        for song in songs {
            song.download()
        }
    }
    func queue() {
        let store: Store = Resolver.resolve()
        let songs = store.songsRecursive(serverId: serverId, level: level, parentPathComponent: name)
        for song in songs {
            song.queue()
        }
    }
}
