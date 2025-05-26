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
    private var coverArtLoader: CoverArtLoader? = nil
    
    init() {
        super.init(frame: .zero)
        image = CoverArtLoader.defaultCoverArtImage(isLarge: isLarge)
    }
    
    init(frame: CGRect = .zero, isLarge: Bool = false) {
        self.isLarge = isLarge
        super.init(frame: frame)
        image = CoverArtLoader.defaultCoverArtImage(isLarge: isLarge)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    func setIdsAndLoad(serverId: Int?, coverArtId: String?) {
        self.serverId = serverId
        self.coverArtId = coverArtId
        load()
    }
    
    func reset() {
        serverId = nil
        coverArtId = nil
        image = CoverArtLoader.defaultCoverArtImage(isLarge: isLarge)
    }
    
    private func load() {
        // Make sure old activity indicator is gone
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil
        
        // Cancel any previous loading
        coverArtLoader?.cancelLoad()
        coverArtLoader?.delegate = nil
        coverArtLoader = nil
        
        guard let coverArtId = coverArtId, let serverId = serverId else {
            // Set default cover art
            image = CoverArtLoader.defaultCoverArtImage(isLarge: isLarge)
            return
        }
        
        let loader = CoverArtLoader(serverId: serverId, coverArtId: coverArtId, isLarge: isLarge, delegate: self)
        if loader.isCached {
            image = loader.coverArtImage
        } else {
            var usedSmallCoverArt = false
            if isLarge {
                // Try and use the small cover art temporarily
                let smallLoader = CoverArtLoader(serverId: serverId, coverArtId: coverArtId, isLarge: false)
                if smallLoader.isCached {
                    image = smallLoader.coverArtImage
                    usedSmallCoverArt = true
                } else {
                    image = loader.defaultCoverArtImage
                }
            } else {
                image = loader.defaultCoverArtImage
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
            loader.startLoad()
        }
        coverArtLoader = loader
    }
}

extension AsyncImageView: APILoaderDelegate {
    func loadingFinished(loader: APILoader?) {
        DDLogInfo("[AsyncImageView] async cover art loading finished for: \(coverArtId ?? "nil")")
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil
        image = coverArtLoader?.coverArtImage
        coverArtLoader = nil
    }
    
    func loadingFailed(loader: APILoader?, error: Error?) {
        DDLogError("[AsyncImageView] async cover art loading failed: \(error?.localizedDescription ?? "unknown error")")
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil
        coverArtLoader = nil
    }
}
