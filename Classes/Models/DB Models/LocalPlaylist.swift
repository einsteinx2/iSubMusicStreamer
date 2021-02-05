//
//  LocalPlaylist.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

struct LocalPlaylist: Codable, Equatable {
    struct Default {
        static let playQueueId = 1
        static let shuffleQueueId = 2
        static let jukeboxPlayQueueId = 3
        static let jukeboxShuffleQueueId = 4
        static let maxDefaultId = jukeboxShuffleQueueId
    }
    
    let id: Int
    var name: String
    var songCount: Int
    var isBookmark: Bool
    var createdDate: Date
    
    init(id: Int, name: String, songCount: Int = 0, isBookmark: Bool = false, createdDate: Date = Date()) {
        self.id = id
        self.name = name
        self.songCount = songCount
        self.isBookmark = isBookmark
        self.createdDate = createdDate
    }

    static func ==(lhs: LocalPlaylist, rhs: LocalPlaylist) -> Bool {
        return lhs.id == rhs.id
    }
}

extension LocalPlaylist: TableCellModel {
    private var store: Store { Resolver.resolve() }
    
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? { songCount == 1 ? "1 song" : "\(songCount) songs" }
    var durationLabelText: String? { nil }
    var coverArtId: String? { nil }
    var isCached: Bool { false }
    func download() {
        for position in 0..<self.songCount {
            store.song(localPlaylistId: id, position: position)?.download()
        }
    }
    func queue() {
        for position in 0..<self.songCount {
            store.song(localPlaylistId: id, position: position)?.queue()
        }
    }
}
