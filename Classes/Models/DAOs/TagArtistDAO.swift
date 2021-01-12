//
//  TagArtistDAO.swift
//  iSub
//
//  Created by Benjamin Baron on 12/27/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

@objc final class TagArtistDAO: NSObject {
    @Injected private var store: Store
    
    var serverId = Settings.shared().currentServerId
    private let tagArtistId: Int
    private var loader: TagArtistLoader?
    private var tagAlbumIds = [Int]()
    
    @objc weak var delegate: APILoaderDelegate?
    
    @objc var hasLoaded: Bool { tagAlbumIds.count > 0 }
    @objc var albumCount: Int { tagAlbumIds.count }
    
    @objc init(tagArtistId: Int, delegate: APILoaderDelegate?) {
        self.tagArtistId = tagArtistId
        self.delegate = delegate
        super.init()
        loadFromCache()
    }
    
    deinit {
        loader?.cancelLoad()
        loader?.callback = nil
    }
    
    @objc func tagAlbum(indexPath: IndexPath) -> TagAlbum? {
        guard indexPath.row < tagAlbumIds.count else { return nil }
        return store.tagAlbum(serverId: serverId, id: tagAlbumIds[indexPath.row])
    }
    
    private func loadFromCache() {
        tagAlbumIds = store.tagAlbumIds(serverId: serverId, tagArtistId: tagArtistId, orderBy: .year)
    }
}

@objc extension TagArtistDAO: APILoaderManager {
    func startLoad() {
        loader = TagArtistLoader(tagArtistId: tagArtistId) { [unowned self] success, error in
            tagAlbumIds = loader?.tagAlbumIds ?? [Int]()
            loader = nil
            
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
