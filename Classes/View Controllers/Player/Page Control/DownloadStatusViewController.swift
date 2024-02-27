//
//  DownloadStatusViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 11/23/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import Resolver

final class DownloadStatusViewController: UIViewController {
    @Injected private var settings: SavedSettings
    @Injected private var downloadsManager: DownloadsManager
    @Injected private var playQueue: PlayQueue
    
    let currentSongProgressBar = UIProgressView(progressViewStyle: .default)
    let nextSongProgressBar = UIProgressView(progressViewStyle: .default)
        
    lazy var songsDownloadedLabel: UILabel = { return makeInfoLabel(text: "0") }()
    lazy var downloadSpaceUsedLabel: UILabel = { return makeInfoLabel(text: "0") }()
    lazy var downloadSizeLabel: UILabel = { return makeInfoLabel(text: "0") }()
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
        view.backgroundColor = .black
        
        let titleLabel = UILabel()
        titleLabel.textColor = .white
        titleLabel.font = .boldSystemFont(ofSize: 30)
        titleLabel.textAlignment = .center
        titleLabel.text = "Download Status"
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
        let downloadSizeTitle = settings.cachingType == CachingType.minSpace.rawValue ? "Min Free Space:" : "Max Download Space:"
        infoTitleStackView.addArrangedSubviews([makeInfoLabel(text: "Songs Downloaded:"),
                                                makeInfoLabel(text: "Download Space Used:"),
                                                makeInfoLabel(text: downloadSizeTitle),
                                                makeInfoLabel(text: "Free Space:")])
        containerView.addSubview(infoTitleStackView)
        infoTitleStackView.snp.makeConstraints { make in
            make.width.equalTo(180)
            make.leading.bottom.equalToSuperview()
            make.top.equalTo(progressBarStackView.snp.bottom).offset(20)
        }
        
        let infoLabelStackView = UIStackView()
        infoLabelStackView.axis = .vertical
        infoLabelStackView.distribution = .equalSpacing
        infoLabelStackView.spacing = 3
        infoLabelStackView.addArrangedSubviews([songsDownloadedLabel,
                                                downloadSpaceUsedLabel,
                                                downloadSizeLabel,
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
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(songDownloadObjects), name: Notifications.songPlaybackStarted)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(songDownloadObjects), name: Notifications.songPlaybackEnded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(songDownloadObjects), name: Notifications.currentPlaylistIndexChanged)
        songDownloadObjects()
        startUpdatingStats()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopUpdatingStats()
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    @objc private func songDownloadObjects() {
        currentSong = playQueue.currentSong
        nextSong = playQueue.nextSong
    }
    
    @objc private func startUpdatingStats() {
        stopUpdatingStats()
        
        if settings.isJukeboxEnabled {
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
        
        let numCachedSongs = downloadsManager.numberOfCachedSongs
        songsDownloadedLabel.text = numCachedSongs == 1 ? "1 song" : "\(numCachedSongs) songs"
        downloadSpaceUsedLabel.text = formatFileSize(bytes: downloadsManager.cacheSize)
        if settings.cachingType == CachingType.minSpace.rawValue {
            downloadSizeLabel.text = formatFileSize(bytes: settings.minFreeSpace)
        } else {
            downloadSizeLabel.text = formatFileSize(bytes: settings.minFreeSpace)
        }
        freeSpaceLabel.text = formatFileSize(bytes: downloadsManager.freeSpace)
        
        perform(#selector(startUpdatingStats), with: nil, afterDelay: 1.0)
    }
    
    private func stopUpdatingStats() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(startUpdatingStats), object: nil)
    }
}
