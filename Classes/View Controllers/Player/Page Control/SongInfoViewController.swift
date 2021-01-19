//
//  SongInfoViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 11/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import Resolver

final class SongInfoViewController: UIViewController {
    @Injected private var audioEngine: AudioEngine
    @Injected private var playQueue: PlayQueue
    
    let stackView = UIStackView()
    var realTimeBitrateLabel: UILabel?
    
    override func viewDidLoad() {
        view.backgroundColor = .black
        
        let titleLabel = UILabel()
        titleLabel.textColor = .white
        titleLabel.font = .boldSystemFont(ofSize: 30)
        titleLabel.textAlignment = .center;
        titleLabel.text = "Song Info";
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.height.equalTo(45)
            make.leading.trailing.top.equalToSuperview()
        }
        
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.trailing.bottom.equalToSuperview().offset(-10)
            make.top.equalTo(titleLabel.snp.bottom)
        }
        
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .equalSpacing
        stackView.spacing = 5
        scrollView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.leading.trailing.top.bottom.equalToSuperview()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateSongInfo()
        startUpdatingRealtimeBitrate()
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(updateSongInfo), name: ISMSNotification_SongPlaybackStarted)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopUpdatingRealtimeBitrate()
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_SongPlaybackStarted)
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    @objc private func updateSongInfo() {
        for infoView in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(infoView)
            infoView.removeFromSuperview()
        }
        realTimeBitrateLabel = nil
        
        func createTitleLabel(text: String) -> UILabel {
            let titleLabel = UILabel()
            titleLabel.textColor = .white
            titleLabel.font = .boldSystemFont(ofSize: 20)
            titleLabel.numberOfLines = 1
            titleLabel.text = text
            return titleLabel
        }
        
        func createInfoLabel(text: String) -> UILabel {
            let infoLabel = UILabel()
            infoLabel.textColor = .lightGray
            infoLabel.font = .systemFont(ofSize: 16)
            infoLabel.numberOfLines = 0
            infoLabel.lineBreakMode = .byCharWrapping
            infoLabel.text = text
            return infoLabel
        }
        
        if let song = playQueue.currentSong {
//            if let path = song.path {
//                stackView.addArrangedSubview(createTitleLabel(text: "File Name"))
//                let filename = (path as NSString).lastPathComponent
//                stackView.addArrangedSubview(createInfoLabel(text: filename))
//            }
            stackView.addArrangedSubview(createTitleLabel(text: "File Path"))
            stackView.addArrangedSubview(createInfoLabel(text: song.path))
            
            stackView.addArrangedSubview(createTitleLabel(text: "Original File Type"))
            stackView.addArrangedSubview(createInfoLabel(text: song.suffix.uppercased()))
            
            if let transcodedSuffix = song.transcodedSuffix {
                stackView.addArrangedSubview(createTitleLabel(text: "Transcoded File Type"))
                stackView.addArrangedSubview(createInfoLabel(text: transcodedSuffix.uppercased()))
            } else {
                stackView.addArrangedSubview(createTitleLabel(text: "Transcoded File Type"))
                stackView.addArrangedSubview(createInfoLabel(text: "Not transcoded"))
            }
            
            stackView.addArrangedSubview(createTitleLabel(text: "Original Bitrate"))
            stackView.addArrangedSubview(createInfoLabel(text: "\(song.bitrate) Kbps"))
            
            realTimeBitrateLabel = createInfoLabel(text: "Unknown")
            
            if let realTimeBitrateLabel = realTimeBitrateLabel {
                stackView.addArrangedSubview(createTitleLabel(text: "Realtime Bitrate"))
                stackView.addArrangedSubview(realTimeBitrateLabel)
            }
            
            stackView.addArrangedSubview(createTitleLabel(text: "Title"))
            stackView.addArrangedSubview(createInfoLabel(text: song.title))
            
            if let tagArtistName = song.tagArtistName {
                stackView.addArrangedSubview(createTitleLabel(text: "Artist"))
                stackView.addArrangedSubview(createInfoLabel(text: tagArtistName))
            }
            
            if let tagAlbumName = song.tagAlbumName {
                stackView.addArrangedSubview(createTitleLabel(text: "Album"))
                stackView.addArrangedSubview(createInfoLabel(text: tagAlbumName))
            }
            
            if song.year > 0 {
                stackView.addArrangedSubview(createTitleLabel(text: "Year"))
                stackView.addArrangedSubview(createInfoLabel(text: "\(song.year)"))
            }
            
            if let genre = song.genre {
                stackView.addArrangedSubview(createTitleLabel(text: "Genre"))
                stackView.addArrangedSubview(createInfoLabel(text: genre))
            }
            
            if song.track > 0 {
                stackView.addArrangedSubview(createTitleLabel(text: "Track Number"))
                stackView.addArrangedSubview(createInfoLabel(text: "\(song.track)"))
            }
            
            if song.discNumber > 0 {
                stackView.addArrangedSubview(createTitleLabel(text: "Disc Number"))
                stackView.addArrangedSubview(createInfoLabel(text: "\(song.discNumber)"))
            }
        }
    }
    
    @objc private func startUpdatingRealtimeBitrate() {
        stopUpdatingRealtimeBitrate()
        if let realTimeBitrateLabel = realTimeBitrateLabel {
            if let player = audioEngine.player, let bitrate = audioEngine.player?.bitRate, bitrate > 0, player.isPlaying {
                realTimeBitrateLabel.text = "\(bitrate) Kbps"
            } else {
                realTimeBitrateLabel.text = "Unknown"
            }
        }
        
        perform(#selector(startUpdatingRealtimeBitrate), with: nil, afterDelay: 0.5)
    }
    
    private func stopUpdatingRealtimeBitrate() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(startUpdatingRealtimeBitrate), object: nil)
    }
}
