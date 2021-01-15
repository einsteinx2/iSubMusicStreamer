//
//  AlbumTableViewHeader.swift
//  iSub
//
//  Created by Benjamin Baron on 11/13/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

@objc final class AlbumTableViewHeader: UIView {
    private let coverArtView = AsyncImageView()
    private let coverArtButton = UIButton(type: .custom)
    private let artistLabel = AutoScrollingLabel()
    private let albumLabel = AutoScrollingLabel()
    private let tracksLabel = UILabel()
    
    @objc init(folderAlbum: FolderAlbum, tracks: Int, duration: Double) {
        super.init(frame: CGRect.zero)
        setup(coverArtId: folderAlbum.coverArtId, artistName: folderAlbum.tagArtistName, name: folderAlbum.name, tracks: tracks, duration: duration)
    }
    
    @objc init(tagAlbum: TagAlbum) {
        super.init(frame: CGRect.zero)
        setup(coverArtId: tagAlbum.coverArtId, artistName: tagAlbum.tagArtistName, name: tagAlbum.name, tracks: tagAlbum.songCount, duration: Double(tagAlbum.duration))
    }
    
    private func setup(coverArtId: String?, artistName: String?, name: String, tracks: Int, duration: Double) {
        backgroundColor = Colors.background
        snp.makeConstraints { make in
            make.height.equalTo(100)
        }
        
        // NOTE: Set to false because scaling down very large images causes flickering
        //       when the view is scaled while dismissing a modal view
        coverArtView.isLarge = false
        coverArtView.coverArtId = coverArtId
        coverArtView.backgroundColor = .label
        addSubview(coverArtView)
        coverArtView.snp.makeConstraints { make in
            make.width.equalTo(coverArtView.snp.height)
            make.leading.equalToSuperview().offset(10)
            make.top.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-10)
        }
        
        if let coverArtId = coverArtId {
            coverArtButton.addClosure(for: .touchUpInside) { [unowned self] in
                let controller = ModalCoverArtViewController()
                controller.coverArtId = coverArtId
                self.viewController?.present(controller, animated: true, completion: nil)
            }
        }
        addSubview(coverArtButton)
        coverArtButton.snp.makeConstraints { make in
            make.leading.trailing.top.bottom.equalTo(coverArtView)
        }
        
        let labelContainer = UIView()
        addSubview(labelContainer)
        labelContainer.snp.makeConstraints { make in
            make.leading.equalTo(coverArtView.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.top.bottom.equalTo(coverArtView)
        }
        
        artistLabel.text = artistName
        artistLabel.font = .boldSystemFont(ofSize: 18)
        artistLabel.textColor = .label
        labelContainer.addSubview(artistLabel)
        artistLabel.snp.makeConstraints { make in
            make.width.leading.trailing.top.equalToSuperview()
            make.height.equalToSuperview().multipliedBy(0.27)
        }
        
        albumLabel.text = name
        albumLabel.font = .systemFont(ofSize: 16)
        albumLabel.textColor = .label
        labelContainer.addSubview(albumLabel)
        albumLabel.snp.makeConstraints { make in
            make.width.height.leading.trailing.equalTo(artistLabel)
            make.top.equalTo(artistLabel.snp.bottom)
        }
        
        let tracksString = tracks == 1 ? "1 track" : "\(tracks) tracks"
        let durationString = NSString.formatTime(duration)
        var finalString = tracksString
        if let durationString = durationString {
            finalString += " • \(durationString) minutes"
        }
        tracksLabel.text = finalString
        tracksLabel.font = .systemFont(ofSize: 14)
        tracksLabel.adjustsFontSizeToFitWidth = true
        tracksLabel.minimumScaleFactor = 0.5
        tracksLabel.textColor = .secondaryLabel
        labelContainer.addSubview(tracksLabel)
        tracksLabel.snp.makeConstraints { make in
            make.height.equalTo(labelContainer).multipliedBy(0.2)
            make.width.leading.bottom.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
}

private final class ModalCoverArtViewController: UIViewController {
    private let closeButton = UIButton(type: .close)
    
    private let coverArt = AsyncImageView(isLarge: true)
    
    var coverArtId: String? {
        get { return coverArt.coverArtId }
        set { coverArt.coverArtId = newValue }
    }
    
    var image: UIImage? {
        get { return coverArt.image }
        set { coverArt.image = newValue }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        view.setNeedsUpdateConstraints()
    }
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        if UIApplication.orientation().isPortrait {
            coverArt.snp.remakeConstraints { make in
                make.width.equalToSuperview()
                make.height.equalTo(coverArt.snp.width)
                make.centerY.equalToSuperview()
            }
        } else {
            coverArt.snp.remakeConstraints { make in
                make.height.equalToSuperview()
                make.width.equalTo(coverArt.snp.height)
                make.centerX.equalToSuperview()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.overrideUserInterfaceStyle = .dark
        view.backgroundColor = Colors.background
        
        coverArt.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(coverArt)
        
        closeButton.addClosure(for: .touchUpInside) { [unowned self] in
            self.dismiss(animated: true, completion: nil)
        }
        view.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(10)
        }
    }
}
