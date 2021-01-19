//
//  LocalPlaylist.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

@objc final class LocalPlaylist: NSObject, NSCopying, Codable {
    struct Default {
        static let playQueueId = 1
        static let shuffleQueueId = 2
        static let jukeboxPlayQueueId = 3
        static let jukeboxShuffleQueueId = 4
        static let maxDefaultId = jukeboxShuffleQueueId
    }
    
    @objc(playlistId) let id: Int
    @objc var name: String
    @objc var songCount: Int
    
    @objc init(id: Int, name: String, songCount: Int) {
        self.id = id
        self.name = name
        self.songCount = songCount
        super.init()
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        LocalPlaylist(id: id, name: name, songCount: songCount)
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? LocalPlaylist {
            return self === object || id == object.id
        }
        return false
    }
    
    override var description: String {
        "\(super.description): id: \(id), name: \(name), songCount: \(songCount)"
    }
}

extension LocalPlaylist: TableCellModel {
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? { songCount == 1 ? "1 song" : "\(songCount) songs" }
    var durationLabelText: String? { nil }
    var coverArtId: String? { nil }
    var isCached: Bool { false }
    func download() {
        let store: Store = Resolver.resolve()
        for position in 0..<self.songCount {
            store.song(localPlaylistId: id, position: position)?.download()
        }
    }
    
    func queue() {
        let store: Store = Resolver.resolve()
        for position in 0..<self.songCount {
            store.song(localPlaylistId: id, position: position)?.queue()
        }
    }
}
