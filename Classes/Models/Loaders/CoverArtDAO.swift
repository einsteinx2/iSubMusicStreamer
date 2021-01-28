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
final class CoverArtDAO {
    @Injected private var store: Store
    
    weak var delegate: APILoaderDelegate?
    private var loader: CoverArtLoader?
    
    var serverId = Settings.shared().currentServerId
    private let coverArtId: String
    private let isLarge: Bool
    
    static func defaultCoverArtImage(isLarge: Bool) -> UIImage? {
        isLarge ? UIImage(named: "default-album-art") : UIImage(named: "default-album-art-small")
    }
    
    var defaultCoverArtImage: UIImage? {
        Self.defaultCoverArtImage(isLarge: isLarge)
    }
    
    var coverArtImage: UIImage? {
        store.coverArt(serverId: serverId, id: coverArtId, isLarge: isLarge)?.image ?? defaultCoverArtImage
    }
    
    var isCached: Bool {
        store.isCoverArtCached(serverId: serverId, id: coverArtId, isLarge: isLarge)
    }
    
    init(coverArtId: String, isLarge: Bool, delegate: APILoaderDelegate? = nil) {
        self.coverArtId = coverArtId
        self.isLarge = isLarge
        self.delegate = delegate
    }
    
    deinit {
        loader?.cancelLoad()
        loader?.delegate = nil
    }
    
    func downloadArtIfNotExists() {
        guard !isCached else { return }
        startLoad()
    }
    
    func startLoad() {
        cancelLoad()
        loader = CoverArtLoader(serverId: serverId, coverArtId: coverArtId, isLarge: isLarge, delegate: self)
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
    
    func loadingFailed(loader: APILoader?, error: Error?) {
        self.loader?.delegate = nil
        self.loader = nil
        delegate?.loadingFailed(loader: nil, error: error)
    }
}
