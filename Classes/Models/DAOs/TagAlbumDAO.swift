//
//  TagAlbumDAO.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

@objc final class TagAlbumDAO: NSObject {
    @Injected private var store: Store
    
    var serverId = Settings.shared().currentServerId
    private let tagAlbumId: Int
    private var loader: TagAlbumLoader?
    private var songIds = [Int]()

    @objc weak var delegate: APILoaderDelegate?

    @objc var hasLoaded: Bool { songIds.count > 0 }
    @objc var songCount: Int { songIds.count }

    @objc init(tagAlbumId: Int, delegate: APILoaderDelegate?) {
        self.tagAlbumId = tagAlbumId
        self.delegate = delegate
        super.init()
        loadFromCache()
    }

    deinit {
        loader?.cancelLoad()
        loader?.callback = nil
    }

    @objc func song(indexPath: IndexPath) -> Song? {
        guard indexPath.row < songIds.count else { return nil }
        return store.song(serverId: serverId, id: songIds[indexPath.row])
    }
    
    @objc func playSong(indexPath: IndexPath) -> Song? {
        guard indexPath.row < songIds.count else { return nil }
        return store.playSong(position: indexPath.row, songIds: songIds, serverId: serverId)
    }
    
    private func loadFromCache() {
        songIds = store.songIds(serverId: serverId, tagAlbumId: tagAlbumId)
    }
}

@objc extension TagAlbumDAO: APILoaderManager {
    func startLoad() {
        loader = TagAlbumLoader(tagAlbumId: tagAlbumId) { [unowned self] success, error in
            songIds = self.loader?.songIds ?? []
            self.loader = nil

            if success {
                delegate?.loadingFinished(loader: nil)
            } else {
                delegate?.loadingFailed(loader: nil, error: error as NSError?)
            }
        }
        loader?.startLoad()
    }

    func cancelLoad() {
        loader?.cancelLoad()
        loader = nil
    }
}
