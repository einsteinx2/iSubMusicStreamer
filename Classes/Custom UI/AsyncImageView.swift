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

@objc class AsyncImageView: UIImageView {
    @objc var isLarge: Bool = false
    @objc var coverArtId: String? = nil {
        didSet {
            load()
        }
    }
    
    private var activityIndicator: UIActivityIndicatorView? = nil
    private var coverArtDAO: CoverArtDAO? = nil
    
    @objc init() {
        super.init(frame: .zero)
        image = CoverArtDAO.defaultCoverArtImage(isLarge)
    }
    
    @objc init(frame: CGRect = .zero, coverArtId: String? = nil, isLarge: Bool = false) {
        self.coverArtId = coverArtId
        self.isLarge = isLarge
        super.init(frame: frame)
        image = CoverArtDAO.defaultCoverArtImage(isLarge)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    @objc func load() {
        // Make sure old activity indicator is gone
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil
        
        // Cancel any previous loading
        coverArtDAO?.cancelLoad()
        coverArtDAO?.delegate = nil
        coverArtDAO = nil
        
        guard let coverArtId = coverArtId else { return }
        
        let dao = CoverArtDAO(delegate: self, coverArtId: coverArtId, isLarge: isLarge)
        if dao.isCoverArtCached {
            image = dao.coverArtImage()
        } else {
            var usedSmallCoverArt = false
            if isLarge {
                // Try and use the small cover art temporarily
                let smallDAO = CoverArtDAO(delegate: nil, coverArtId: coverArtId, isLarge: false)
                if smallDAO.isCoverArtCached {
                    image = smallDAO.coverArtImage()
                    usedSmallCoverArt = true
                } else {
                    image = dao.defaultCoverArtImage()
                }
            } else {
                image = dao.defaultCoverArtImage()
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
            dao.startLoad()
        }
        coverArtDAO = dao
    }
}

extension AsyncImageView: SUSLoaderDelegate {
    func loadingFinished(_ loader: SUSLoader!) {
        DDLogInfo("[AsyncImageView] async cover art loading finished for: \(coverArtId ?? "nil")")
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil
        image = coverArtDAO?.coverArtImage()
        coverArtDAO = nil
    }
    
    func loadingFailed(_ loader: SUSLoader!, withError error: Error!) {
        DDLogError("[AsyncImageView] async cover art loading failed: \(error?.localizedDescription ?? "unknown error")")
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil
        coverArtDAO = nil
    }
}
