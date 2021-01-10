//
//  LocalPlaylist.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

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
        return LocalPlaylist(id: id, name: name, songCount: songCount)
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? LocalPlaylist {
            return self === object || id == object.id
        }
        return false
    }
    
    override var description: String {
        return "\(super.description): id: \(id), name: \(name), songCount: \(songCount)"
    }
}

extension LocalPlaylist: TableCellModel {
    var primaryLabelText: String? { name }
    var secondaryLabelText: String? { songCount == 1 ? "1 song" : "\(songCount) songs" }
    var durationLabelText: String? { nil }
    var coverArtId: String? { nil }
    var isCached: Bool { false }
    
    func download() {
        // TODO: implement this
        //    [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
        //
        //    [EX2Dispatch runInBackgroundAfterDelay:0.05 block:^{
        //        for (int i = 0; i < self.count; i++) {
        //            [[ISMSSong songFromDbRow:i inTable:self.databaseTable inDatabaseQueue:databaseS.localPlaylistsDbQueue] addToDownloadQueue];
        //        }
        //
        //        [EX2Dispatch runInMainThreadAsync:^{
        //            [viewObjectsS hideLoadingScreen];
        //        }];
        //    }];
    }
    
    func queue() {
        // TODO: implement this
        //    [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
        //
        //    [EX2Dispatch runInBackgroundAfterDelay:0.05 block:^{
        //        for (int i = 0; i < self.count; i++) {
        //            [[ISMSSong songFromDbRow:i inTable:self.databaseTable inDatabaseQueue:databaseS.localPlaylistsDbQueue] addToCurrentPlaylistDbQueue];
        //        }
        //
        //        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
        //
        //        [EX2Dispatch runInMainThreadAsync:^{
        //            [viewObjectsS hideLoadingScreen];
        //        }];
        //    }];
    }
}
