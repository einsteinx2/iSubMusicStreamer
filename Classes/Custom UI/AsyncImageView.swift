//
//  AsyncImageView.swift
//  iSub
//
//  Created by Benjamin Baron on 12/6/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import CocoaLumberjackSwift

final class AsyncImageView: UIImageView {
    var isLarge: Bool = false
    private(set) var serverId: Int? = nil
    private(set) var coverArtId: String? = nil
    
    private var activityIndicator: UIActivityIndicatorView? = nil
    private let manager: AsyncCoverArtLoaderManager
    private var downloadTask: Task<Void, Never>?
    
    init(manager: AsyncCoverArtLoaderManager = AsyncCoverArtLoaderManager.shared) {
        self.manager = manager
        super.init(frame: .zero)
        image = AsyncCoverArtLoaderManager.defaultCoverArtImage(isLarge: isLarge)
    }
    
    init(frame: CGRect = .zero, isLarge: Bool = false, manager: AsyncCoverArtLoaderManager = AsyncCoverArtLoaderManager.shared) {
        self.isLarge = isLarge
        self.manager = manager
        super.init(frame: frame)
        image = AsyncCoverArtLoaderManager.defaultCoverArtImage(isLarge: isLarge)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    func setIdsAndLoad(serverId: Int?, coverArtId: String?) {
        if self.serverId != serverId || self.coverArtId != coverArtId, let oldServerId = self.serverId, let oldCoverArtId = self.coverArtId {
            Task {
                await manager.cancel(serverId: oldServerId, coverArtId: oldCoverArtId, isLarge: isLarge)
            }
        }
        
        self.serverId = serverId
        self.coverArtId = coverArtId
        load()
    }
    
    func reset() {
        serverId = nil
        coverArtId = nil
        image = AsyncCoverArtLoaderManager.defaultCoverArtImage(isLarge: isLarge)
    }
    
    private func load() {
        // Make sure old activity indicator is gone
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil
        
        // Cancel any previous loading
        downloadTask?.cancel()
        downloadTask = nil
        
        guard let coverArtId, let serverId else {
            // Set default cover art
            image = AsyncCoverArtLoaderManager.defaultCoverArtImage(isLarge: isLarge)
            return
        }
        
        let loadingId = CoverArtLoadingId(serverId: serverId, coverArtId: coverArtId, isLarge: isLarge)
        
        if manager.isCached(loadingId: loadingId) {
            image = manager.coverArtImage(loadingId: loadingId)
        } else {
            downloadTask = Task {
                var usedSmallCoverArt = false
                if isLarge {
                    // Try and use the small cover art temporarily
                    if manager.isCached(serverId: serverId, coverArtId: coverArtId, isLarge: false) {
                        image = manager.coverArtImage(serverId: serverId, coverArtId: coverArtId, isLarge: false)
                        usedSmallCoverArt = true
                    } else {
                        image = AsyncCoverArtLoaderManager.defaultCoverArtImage(isLarge: isLarge)
                    }
                } else {
                    image = AsyncCoverArtLoaderManager.defaultCoverArtImage(isLarge: true)
                }
                
                if isLarge && !usedSmallCoverArt {
                    let indicator = UIActivityIndicatorView(style: .large)
                    addSubview(indicator)
                    indicator.snp.makeConstraints { make in
                        make.leading.trailing.top.bottom.equalToSuperview()
                    }
                    indicator.startAnimating()
                    activityIndicator = indicator
                }
                
                if let coverArt = await manager.download(loadingId: loadingId) {
                    DDLogInfo("[AsyncImageView] async cover art loading finished for \(loadingId)")
                    activityIndicator?.removeFromSuperview()
                    activityIndicator = nil
                    image = coverArt.image
                } else {
                    DDLogError("[AsyncImageView] async cover art loading failed for \(loadingId)")
                    activityIndicator?.removeFromSuperview()
                    activityIndicator = nil
                }
                
            }
        }
    }
}
