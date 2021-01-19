//
//  CoverArtDAO.swift
//  iSub
//
//  Created by Benjamin Baron on 1/8/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

// TODO: Get rid of this class and just use the CoverArtLoader
@objc final class CoverArtDAO: NSObject {
    @Injected private var store: Store
    
    @objc weak var delegate: APILoaderDelegate?
    private var loader: CoverArtLoader?
    
    @objc var serverId = Settings.shared().currentServerId
    private let coverArtId: String
    private let isLarge: Bool
    
    @objc static func defaultCoverArtImage(isLarge: Bool) -> UIImage? {
        isLarge ? UIImage(named: "default-album-art") : UIImage(named: "default-album-art-small")
    }
    
    @objc var defaultCoverArtImage: UIImage? {
        Self.defaultCoverArtImage(isLarge: isLarge)
    }
    
    @objc var coverArtImage: UIImage? {
        store.coverArt(serverId: serverId, id: coverArtId, isLarge: isLarge)?.image ?? defaultCoverArtImage
    }
    
    @objc var isCached: Bool {
        store.isCoverArtCached(serverId: serverId, id: coverArtId, isLarge: isLarge)
    }
    
    @objc init(coverArtId: String, isLarge: Bool, delegate: APILoaderDelegate?) {
        self.coverArtId = coverArtId
        self.isLarge = isLarge
        self.delegate = delegate
        super.init()
    }
    
    deinit {
        loader?.cancelLoad()
        loader?.delegate = nil
    }
    
    @objc func downloadArtIfNotExists() {
        if !isCached {
            startLoad()
        }
    }
}

@objc extension CoverArtDAO: APILoaderManager {
    func startLoad() {
        cancelLoad()
        loader = CoverArtLoader(coverArtId: coverArtId, isLarge: isLarge, delegate: self)
        loader?.serverId = serverId
        loader?.startLoad()
    }
    
    func cancelLoad() {
        loader?.cancelLoad()
        loader?.delegate = nil
        loader = nil
    }
}

extension CoverArtDAO: APILoaderDelegate {
    func loadingFinished(loader: APILoader?) {
        self.loader?.delegate = nil
        self.loader = nil
        delegate?.loadingFinished(loader: nil)
    }
    
    func loadingFailed(loader: APILoader?, error: NSError?) {
        self.loader?.delegate = nil
        self.loader = nil
        delegate?.loadingFailed(loader: nil, error: error)
    }
}
