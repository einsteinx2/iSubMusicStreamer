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
        var subfoldersText: String? = nil
        var songsText: String? = nil
        if let count = store.downloadedFolderAlbumsCount(downloadedFolderArtist: self), count > 0 {
            subfoldersText = "\(count) \("Folder".pluralize(amount: count))"
        }
        if let count = store.downloadedSongsCount(downloadedFolderArtist: self), count > 0 {
            songsText = "\(count) \("Song".pluralize(amount: count))"
        }
        return [subfoldersText, songsText].compactMap({ $0 }).joined(separator: " • ")
    }
    var durationLabelText: String? { nil }
    var coverArtId: String? { nil }
    var isDownloaded: Bool { true }
    var isDownloadable: Bool { false }
    
    var tagArtistId: Int? { nil }
    var tagAlbumId: Int? { nil }
    var parentFolderId: Int? { nil }
    
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
    func queueNext() {
        // TODO: implement this
        fatalError("implement this")
    }
}
