//
//  CacheStatusViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 11/23/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit

final class CacheStatusViewController: UIViewController {
    let currentSongProgressBar = UIProgressView(progressViewStyle: .default)
    let nextSongProgressBar = UIProgressView(progressViewStyle: .default)
        
    lazy var songsCachedLabel: UILabel = { return makeInfoLabel(text: "0") }()
    lazy var cachedUsedLabel: UILabel = { return makeInfoLabel(text: "0") }()
    lazy var cacheSizeLabel: UILabel = { return makeInfoLabel(text: "0") }()
    lazy var freeSpaceLabel: UILabel = { return makeInfoLabel(text: "0") }()
    
    var currentSong: Song?
    var nextSong: Song?
    
    private func makeTitleLabel(text: String) -> UILabel {
        let label = UILabel()
        label.textColor = .white
        label.font = .boldSystemFont(ofSize: 20)
        label.text = text
        return label
    }
    
    private func makeInfoLabel(text: String) -> UILabel {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 16)
        label.text = text
        return label
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        let titleLabel = UILabel()
        titleLabel.textColor = .white
        titleLabel.font = .boldSystemFont(ofSize: 30)
        titleLabel.textAlignment = .center
        titleLabel.text = "Cache Status"
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.height.equalTo(45)
            make.leading.trailing.top.equalToSuperview()
        }
        
        let bottomContainerView = UIView()
        view.addSubview(bottomContainerView)
        bottomContainerView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom)
        }
        
        let containerView = UIView()
        bottomContainerView.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
        }
       
        let progressBarStackView = UIStackView()
        progressBarStackView.axis = .vertical
        progressBarStackView.distribution = .equalSpacing
        progressBarStackView.spacing = 10
        progressBarStackView.addArrangedSubviews([makeTitleLabel(text: "Current Song"),
                                                  currentSongProgressBar,
                                                  makeTitleLabel(text: "Next Song"),
                                                  nextSongProgressBar])
        containerView.addSubview(progressBarStackView)
        progressBarStackView.snp.makeConstraints { make in
            make.leading.trailing.top.equalTo(containerView)
        }
        
        currentSongProgressBar.trackTintColor = .darkGray
        currentSongProgressBar.snp.makeConstraints { make in
            make.width.equalToSuperview()
        }
        
        nextSongProgressBar.trackTintColor = .darkGray
        nextSongProgressBar.snp.makeConstraints { make in
            make.width.equalToSuperview()
        }
        
        let infoTitleStackView = UIStackView()
        infoTitleStackView.axis = .vertical
        infoTitleStackView.distribution = .equalSpacing
        infoTitleStackView.spacing = 3
        let cacheSizeTitle = Settings.shared().cachingType == ISMSCachingType_minSpace.rawValue ? "Min Free Space:" : "Max Cache Size:"
        infoTitleStackView.addArrangedSubviews([makeInfoLabel(text: "Songs Cached:"),
                                                makeInfoLabel(text: "Cache Used:"),
                                                makeInfoLabel(text: cacheSizeTitle),
                                                makeInfoLabel(text: "Free Space:")])
        containerView.addSubview(infoTitleStackView)
        infoTitleStackView.snp.makeConstraints { make in
            make.width.equalTo(130)
            make.leading.bottom.equalToSuperview()
            make.top.equalTo(progressBarStackView.snp.bottom).offset(20)
        }
        
        let infoLabelStackView = UIStackView()
        infoLabelStackView.axis = .vertical
        infoLabelStackView.distribution = .equalSpacing
        infoLabelStackView.spacing = 3
        infoLabelStackView.addArrangedSubviews([songsCachedLabel,
                                                cachedUsedLabel,
                                                cacheSizeLabel,
                                                freeSpaceLabel])
        containerView.addSubview(infoLabelStackView)
        infoLabelStackView.snp.makeConstraints { make in
            make.leading.equalTo(infoTitleStackView.snp.trailing)
            make.trailing.bottom.equalToSuperview()
            make.top.equalTo(infoTitleStackView)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(cacheSongObjects), name: ISMSNotification_SongPlaybackStarted)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(cacheSongObjects), name: ISMSNotification_SongPlaybackEnded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(cacheSongObjects), name: ISMSNotification_CurrentPlaylistIndexChanged)
        cacheSongObjects()
        startUpdatingStats()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopUpdatingStats()
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    @objc private func cacheSongObjects() {
        currentSong = PlayQueue.shared().currentSong()
        nextSong = PlayQueue.shared().nextSong()
    }
    
    @objc private func startUpdatingStats() {
        stopUpdatingStats()
        
        if Settings.shared().isJukeboxEnabled {
            currentSongProgressBar.progress = 0
            currentSongProgressBar.alpha = 0.5
            nextSongProgressBar.progress = 0
            nextSongProgressBar.alpha = 0.5
        } else {
            if let currentSong = currentSong, !currentSong.isTempCached {
                currentSongProgressBar.progress = Float(currentSong.downloadProgress)
                currentSongProgressBar.alpha = 1
            } else {
                currentSongProgressBar.progress = 0
                currentSongProgressBar.alpha = 0.5
            }
            
            if let nextSong = nextSong, !nextSong.isTempCached {
                nextSongProgressBar.progress = Float(nextSong.downloadProgress)
                nextSongProgressBar.alpha = 1
            } else {
                nextSongProgressBar.progress = 0
                nextSongProgressBar.alpha = 0.5
            }
        }
        
        let numCachedSongs = Cache.shared().numberOfCachedSongs
        songsCachedLabel.text = numCachedSongs == 1 ? "1 song" : "\(numCachedSongs) songs"
        cachedUsedLabel.text = NSString.formatFileSize(Cache.shared().cacheSize)
        if Settings.shared().cachingType == ISMSCachingType_minSpace.rawValue {
            cacheSizeLabel.text = NSString.formatFileSize(Settings.shared().minFreeSpace)
        } else {
            cacheSizeLabel.text = NSString.formatFileSize(Settings.shared().minFreeSpace)
        }
        freeSpaceLabel.text = NSString.formatFileSize(Cache.shared().freeSpace)
        
        perform(#selector(startUpdatingStats), with: nil, afterDelay: 1.0)
    }
    
    private func stopUpdatingStats() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(startUpdatingStats), object: nil)
    }
}
