//
//  DownloadedFolderAlbum.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

struct DownloadedFolderAlbum: Codable, Equatable {
    let serverId: Int
    let level: Int
    let name: String
    let coverArtId: String?
}

extension DownloadedFolderAlbum: TableCellModel {
    private var store: Store { Resolver.resolve() }
    
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? {
        // TODO: implement this using number of songs downloaded
        nil
    }
    var durationLabelText: String? { nil }
    var isCached: Bool { true }
    func download() {
        let songs = store.songsRecursive(serverId: serverId, level: level, parentPathComponent: name)
        for song in songs {
            song.download()
        }
    }
    func queue() {
        let songs = store.songsRecursive(serverId: serverId, level: level, parentPathComponent: name)
        for song in songs {
            song.queue()
        }
    }
}
