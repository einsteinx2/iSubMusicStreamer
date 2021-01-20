//
//  DownloadedFolderArtist.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class DownloadedFolderArtist: Codable, CustomStringConvertible {
    let serverId: Int
    let name: String
    
    init(serverId: Int, name: String) {
        self.serverId = serverId
        self.name = name
    }
    
    static func ==(lhs: DownloadedFolderArtist, rhs: DownloadedFolderArtist) -> Bool {
        return lhs === rhs || (lhs.serverId == rhs.serverId && lhs.name == rhs.name)
    }
}

extension DownloadedFolderArtist: TableCellModel {
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? {
        // TODO: implement this using number of subfolders downloaded
        return nil
    }
    var durationLabelText: String? { nil }
    var coverArtId: String? { nil }
    var isCached: Bool { true }
    func download() {
        let store: Store = Resolver.resolve()
        let songs = store.songsRecursive(serverId: serverId, level: 0, parentPathComponent: name)
        for song in songs {
            song.download()
        }
    }
    func queue() {
        let store: Store = Resolver.resolve()
        let songs = store.songsRecursive(serverId: serverId, level: 0, parentPathComponent: name)
        for song in songs {
            song.queue()
        }
    }
}
