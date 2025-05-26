//
//  CoverArtViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 11/16/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit

final class CoverArtViewController: UIViewController {
    private let coverArtImageView = AsyncImageView(isLarge: true)
    
    var serverId: Int? { return coverArtImageView.serverId }
    var coverArtId: String? { return coverArtImageView.coverArtId }
    
    var image: UIImage? {
        get { return coverArtImageView.image }
        set { coverArtImageView.image = newValue }
    }
    
    func setIdsAndLoad(serverId: Int?, coverArtId: String?) {
        coverArtImageView.setIdsAndLoad(serverId: serverId, coverArtId: coverArtId)
    }
    
    func reset() {
        coverArtImageView.reset()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(coverArtImageView)
        coverArtImageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(coverArtImageView.snp.width)
        }
    }
}
