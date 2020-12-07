//
//  CoverArtViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 11/16/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit

class CoverArtViewController: UIViewController {
    private let coverArt = AsyncImageView(isLarge: true)
    
    @objc var coverArtId: String? {
        get { return coverArt.coverArtId }
        set { coverArt.coverArtId = newValue }
    }
    
    @objc var image: UIImage? {
        get { return coverArt.image }
        set { coverArt.image = newValue }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(coverArt)
        coverArt.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(coverArt.snp.width)
        }
    }
}
