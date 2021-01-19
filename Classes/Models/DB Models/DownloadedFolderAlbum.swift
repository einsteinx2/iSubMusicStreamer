//
//  DownloadedFolderAlbum.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

@objc final class DownloadedFolderAlbum: NSObject, NSCopying, Codable {
    @objc let serverId: Int
    @objc let level: Int
    @objc let name: String
    @objc let coverArtId: String?
    
    @objc init(serverId: Int, level: Int, name: String, coverArtId: String?) {
        self.serverId = serverId
        self.level = level
        self.name = name
        self.coverArtId = coverArtId
        super.init()
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return DownloadedFolderAlbum(serverId: serverId, level: level, name: name, coverArtId: coverArtId)
    }
    
    override var description: String {
        "\(super.description): serverId: \(serverId), level: \(level), name: \(name), coverArtId: \(coverArtId ?? "nil")"
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
