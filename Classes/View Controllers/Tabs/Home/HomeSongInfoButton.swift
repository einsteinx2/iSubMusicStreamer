//
//  HomeSongInfoButton.swift
//  iSub
//
//  Created by Benjamin Baron on 2/4/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit

final class HomeSongInfoButton: UIView {
    private let coverArt = AsyncImageView()
    private let artistLabel = AutoScrollingLabel()
    private let songLabel = AutoScrollingLabel()
    private let button = UIButton(type: .custom)
    
    init(actionHandler: (() -> ())? = nil) {
        super.init(frame: CGRect.zero)
        
        layer.borderWidth = 2
        layer.borderColor = UIColor.systemGray4.cgColor
        
        coverArt.layer.borderWidth = layer.borderWidth
        coverArt.layer.borderColor = layer.borderColor
        addSubview(coverArt)
        coverArt.snp.makeConstraints { make in
            make.width.equalTo(coverArt.snp.height)
            make.leading.top.bottom.equalToSuperview()
        }
        
        songLabel.font = .boldSystemFont(ofSize: 18)
        songLabel.textColor = .label
        addSubview(songLabel)
        songLabel.snp.makeConstraints { make in
            make.height.equalToSuperview().dividedBy(2)
            make.leading.equalTo(coverArt.snp.trailing).offset(7)
            make.trailing.equalToSuperview().offset(-7)
            make.top.equalToSuperview().offset(5)
        }
        
        artistLabel.font = .systemFont(ofSize: 16)
        artistLabel.textColor = .secondaryLabel
        addSubview(artistLabel)
        artistLabel.snp.makeConstraints { make in
            make.height.leading.trailing.equalTo(songLabel)
            make.bottom.equalToSuperview().offset(-5)
        }
        
        if let actionHandler = actionHandler {
            button.addClosure(for: .touchUpInside, closure: actionHandler)
        }
        addSubview(button)
        button.snp.makeConstraints { make in
            make.leading.trailing.top.bottom.equalToSuperview()
        }
        
        update(song: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    func setAction(handler: @escaping () -> ()) {
        button.addClosure(for: .touchUpInside, closure: handler)
    }
    
    func update(song: Song?) {
        if let song = song {
            coverArt.setIdsAndLoad(serverId: song.serverId, coverArtId: song.coverArtId)
            songLabel.text = song.title
            artistLabel.text = song.tagArtistName
        } else {
            coverArt.image = UIImage(named: "default-album-art-small")
            songLabel.text = nil
            artistLabel.text = nil
        }
    }
}
