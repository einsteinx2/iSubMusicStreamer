//
//  DownloadedFolderArtist.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

struct DownloadedFolderArtist: Codable, Equatable {
    let serverId: Int
    let name: String
}

extension DownloadedFolderArtist: TableCellModel {
    private var store: Store { Resolver.resolve() }
    
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? {
        // TODO: implement this using number of subfolders downloaded
        return nil
    }
    var durationLabelText: String? { nil }
    var coverArtId: String? { nil }
    var isCached: Bool { true }
    func download() {
        let songs = store.songsRecursive(serverId: serverId, level: 0, parentPathComponent: name)
        for song in songs {
            song.download()
        }
    }
    func queue() {
        let songs = store.songsRecursive(serverId: serverId, level: 0, parentPathComponent: name)
        for song in songs {
            song.queue()
        }
    }
}
