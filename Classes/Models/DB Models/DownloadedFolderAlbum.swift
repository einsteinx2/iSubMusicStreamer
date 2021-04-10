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
        var subfoldersText: String? = nil
        var songsText: String? = nil
        if let count = store.downloadedFolderAlbumsCount(downloadedFolderAlbum: self), count > 0 {
            subfoldersText = "\(count) \("Folder".pluralize(amount: count))"
        }
        if let count = store.downloadedSongsCount(downloadedFolderAlbum: self), count > 0 {
            songsText = "\(count) \("Song".pluralize(amount: count))"
        }
        return [subfoldersText, songsText].compactMap({ $0 }).joined(separator: " • ")
    }
    var durationLabelText: String? { nil }
    var isDownloaded: Bool { true }
    var isDownloadable: Bool { false }
    
    var tagArtistId: Int? { nil }
    var tagAlbumId: Int? { nil }
    var parentFolderId: Int? { nil }
    
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
    func queueNext() {
        var offset = 0
        let songs = store.songsRecursive(serverId: serverId, level: 0, parentPathComponent: name)
        for song in songs {
            song.queueNext(offset: offset)
            offset += 1
        }
    }
}
