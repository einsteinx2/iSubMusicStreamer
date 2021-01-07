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
    
    private let tagArtistId: Int
    private var loader: TagArtistLoader?
    private var tagAlbumIds = [Int]()
    
    @objc weak var delegate: SUSLoaderDelegate?
    
    @objc var hasLoaded: Bool { tagAlbumIds.count > 0 }
    @objc var albumCount: Int { tagAlbumIds.count }
    
    @objc init(tagArtistId: Int, delegate: SUSLoaderDelegate?) {
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
        return store.tagAlbum(id: tagAlbumIds[indexPath.row])
    }
    
    private func loadFromCache() {
        tagAlbumIds = store.tagAlbumIds(tagArtistId: tagArtistId, orderBy: .year)
    }
}

@objc extension TagArtistDAO: SUSLoaderManager {
    func startLoad() {
        loader = TagArtistLoader(tagArtistId: tagArtistId) { [unowned self] success, error in
            tagAlbumIds = loader?.tagAlbumIds ?? [Int]()
            loader = nil
            
            if success {
                delegate?.loadingFinished(nil)
            } else {
                delegate?.loadingFailed(nil, withError: error)
            }
        }
        loader?.startLoad()
    }
    
    func cancelLoad() {
        loader?.cancelLoad()
        loader = nil
    }
}
