//
//  CoverArtDAO.swift
//  iSub
//
//  Created by Benjamin Baron on 1/8/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

@objc final class CoverArtDAO: NSObject {
    @Injected private var store: Store
    
    @objc weak var delegate: SUSLoaderDelegate?
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
    
    @objc init(delegate: SUSLoaderDelegate?, coverArtId: String, isLarge: Bool) {
        self.delegate = delegate
        self.coverArtId = coverArtId
        self.isLarge = isLarge
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

@objc extension CoverArtDAO: SUSLoaderManager {
    func startLoad() {
        cancelLoad()
        loader = CoverArtLoader(delegate: self, coverArtId: coverArtId, isLarge: isLarge)
        loader?.serverId = serverId
        loader?.startLoad()
    }
    
    func cancelLoad() {
        loader?.cancelLoad()
        loader?.delegate = nil
        loader = nil
    }
}

extension CoverArtDAO: SUSLoaderDelegate {
    func loadingFinished(_ loader: SUSLoader?) {
        self.loader?.delegate = nil
        self.loader = nil
        delegate?.loadingFinished(nil)
    }
    
    func loadingFailed(_ loader: SUSLoader?, withError error: Error?) {
        self.loader?.delegate = nil
        self.loader = nil
        delegate?.loadingFailed(nil, withError: error)
    }
}
