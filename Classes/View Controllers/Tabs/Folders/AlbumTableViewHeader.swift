//
//  AlbumTableViewHeader.swift
//  iSub
//
//  Created by Benjamin Baron on 11/13/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

@objc class AlbumTableViewHeader: UIView {
    private let coverArtView = AsynchronousImageView()
    private let artistLabel = AutoScrollingLabel()
    private let albumLabel = AutoScrollingLabel()
    private let tracksLabel = UILabel()
    
    @objc init(album: Album, tracks: Int, duration: Double) {
        super.init(frame: CGRect.zero)
        
        backgroundColor = .systemBackground
        snp.makeConstraints { make in
            make.height.equalTo(100)
        }
        
        coverArtView.coverArtId = album.coverArtId
        coverArtView.isLarge = true
        coverArtView.backgroundColor = .label
//        coverArtView.layer.borderWidth = 1
//        coverArtView.layer.borderColor = UIColor.systemGray5.cgColor
        addSubview(coverArtView)
        coverArtView.snp.makeConstraints { make in
            make.width.equalTo(coverArtView.snp.height)
            make.leading.equalToSuperview().offset(10)
            make.top.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-10)
        }
        
        let labelContainer = UIView()
        addSubview(labelContainer)
        labelContainer.snp.makeConstraints { make in
            make.leading.equalTo(coverArtView.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.top.bottom.equalTo(coverArtView)
        }
        
        artistLabel.text = album.artistName
        artistLabel.font = .boldSystemFont(ofSize: 20)
        artistLabel.textColor = .label
        artistLabel.isInsideTableHeader = true
        labelContainer.addSubview(artistLabel)
        artistLabel.snp.makeConstraints { make in
            make.width.leading.trailing.top.equalToSuperview()
            make.height.equalToSuperview().dividedBy(3)
        }
        
        albumLabel.text = album.title
        albumLabel.font = .systemFont(ofSize: 20)
        albumLabel.textColor = .label
        albumLabel.isInsideTableHeader = true
        labelContainer.addSubview(albumLabel)
        albumLabel.snp.makeConstraints { make in
            make.width.height.leading.trailing.equalTo(artistLabel)
            make.top.equalTo(artistLabel.snp.bottom)
        }
        
        let tracksString = tracks == 1 ? "1 Track" : "\(tracks) Tracks"
        let durationString = NSString.formatTime(duration)
        var finalString = tracksString
        if let durationString = durationString {
            finalString += " • \(durationString) Minutes"
        }
        tracksLabel.text = finalString
        tracksLabel.font = .systemFont(ofSize: 20)
        tracksLabel.adjustsFontSizeToFitWidth = true
        tracksLabel.minimumScaleFactor = 0.5
        tracksLabel.textColor = .secondaryLabel
        labelContainer.addSubview(tracksLabel)
        tracksLabel.snp.makeConstraints { make in
            make.width.leading.bottom.equalToSuperview()
            make.height.equalTo(labelContainer).dividedBy(3)
            make.top.equalTo(albumLabel.snp.bottom)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
}
