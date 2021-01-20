//
//  PlayerViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 11/15/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import CocoaLumberjackSwift
import Resolver

// TODO: Add bitrate and file type labels
// TODO: Add bookmark button
@objc final class PlayerViewController: UIViewController {
    @Injected private var settings: Settings
    @Injected private var jukebox: Jukebox
    @Injected private var audioEngine: AudioEngine
    @Injected private var playQueue: PlayQueue
    @Injected private var streamManager: StreamManager
    
    let iconDefaultColor = UIColor(white: 0.8, alpha: 1.0)
    let iconActivatedColor = UIColor.systemBlue
    
    var currentSong: Song?
    
    private var notificationObservers = [NSObjectProtocol]()
    
    // Cover Art
    private let coverArtPageControl = PageControlViewController()
    
    // Stack view for all other UI elements
    private let verticalStackContainer = UIView()
    private let verticalStack = UIStackView()
    
    // Song info
    private let songInfoContainer = UIView()
    private let songNameLabel = AutoScrollingLabel()
    private let artistNameLabel = AutoScrollingLabel()
    
    // Player controls
    private let controlsStack = UIStackView()
    private let playPauseButton = UIButton(type: .custom)
    private let previousButton = UIButton(type: .custom)
    private let nextButton = UIButton(type: .custom)
    private let quickSkipBackButton = UIButton(type: .custom)
    private let quickSkipForwardButton = UIButton(type: .custom)
    
    // More Controls
    private let moreControlsStack = UIStackView()
    private let repeatButton = UIButton(type: .custom)
    private let bookmarksButton = UIButton(type: .custom)
    private let equalizerButton = UIButton(type: .custom)
    private let shuffleButton = UIButton(type: .custom)
    
    // Progress bar
    private var progressDisplayLink: CADisplayLink?
    private let progressBarContainer = UIView()
    private let elapsedTimeLabel = UILabel()
    private let remainingTimeLabel = UILabel()
    private let downloadProgressView = UIView()
    private let progressSlider = OBSlider()
    private var lastSeekTime = Date()
    
    // Jukebox
    private let jukeboxVolumeContainer = UIView()
    private let jukeboxVolumeSlider = UISlider()
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.equalizerButton.isHidden = UIApplication.orientation.isPortrait
        view.setNeedsUpdateConstraints()
    }
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        updateDownloadProgress(animated: false)
        if UIApplication.orientation.isPortrait || UIDevice.isPad() {
            coverArtPageControl.view.snp.remakeConstraints { make in
                make.height.equalTo(coverArtPageControl.view.snp.width).offset(20)
                make.top.leading.equalToSuperview().offset(20)
                make.trailing.equalToSuperview().offset(-20)
            }
            
            verticalStackContainer.snp.remakeConstraints { make in
                if UIDevice.isPad() {
                    make.width.equalTo(coverArtPageControl.view)
                } else {
                    make.width.equalTo(coverArtPageControl.view).multipliedBy(0.9)
                }
                make.centerX.equalTo(coverArtPageControl.view)
                make.top.equalTo(coverArtPageControl.view.snp.bottom)
                make.bottom.equalToSuperview()
            }
            
            verticalStack.snp.remakeConstraints { make in
                make.leading.trailing.equalToSuperview()
                if UIDevice.isSmall() || UIDevice.isPad() {
                    make.height.equalToSuperview().multipliedBy(0.9)
                    make.centerY.equalToSuperview()
                } else {
                    make.height.equalToSuperview().multipliedBy(0.7)
                    make.centerY.equalToSuperview().offset(-20)
                }
            }
        } else {
            coverArtPageControl.view.snp.remakeConstraints { make in
                make.width.equalTo(coverArtPageControl.view.snp.height).offset(-20)
                make.top.equalToSuperview().offset(20)
                make.bottom.equalToSuperview().offset(-20)
                if UIDevice.isSmall() {
                    make.leading.equalToSuperview().offset(20)
                } else {
                    make.centerX.equalToSuperview().multipliedBy(0.5)
                }
            }
            
            verticalStackContainer.snp.remakeConstraints { make in
                make.leading.equalTo(coverArtPageControl.view.snp.trailing).offset(40)
                make.trailing.equalToSuperview().offset(-40)
                make.top.equalToSuperview()
                make.bottom.equalToSuperview()
            }
            
            verticalStack.snp.remakeConstraints { make in
                make.width.equalToSuperview().multipliedBy(0.75)
                make.centerX.equalToSuperview()
                make.height.equalToSuperview().multipliedBy(0.8)
                make.centerY.equalToSuperview().offset(-20)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.overrideUserInterfaceStyle = .dark
        view.backgroundColor = Colors.background
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(image:  UIImage(systemName: "list.number"), style: .plain, target: self, action: #selector(showCurrentPlaylist))
        
        //
        // Cover art
        //
        
        coverArtPageControl.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(coverArtPageControl)
        view.addSubview(coverArtPageControl.view)
        
        
        //
        // Vertical Stack View
        //
        
        verticalStackContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(verticalStackContainer)
        
        verticalStack.translatesAutoresizingMaskIntoConstraints = false
        verticalStack.addArrangedSubviews([songInfoContainer, progressBarContainer, controlsStack, moreControlsStack])
        verticalStack.axis = .vertical
        verticalStack.distribution = .equalSpacing
        verticalStackContainer.addSubview(verticalStack)
        
        //
        // Song Info
        //
        
        songInfoContainer.snp.makeConstraints { make in
            make.width.equalToSuperview()
            make.height.equalTo(UIDevice.isSmall() || UIDevice.isPad() ? 50 : 60)
            make.centerX.equalToSuperview()
        }
        
        songNameLabel.font = .boldSystemFont(ofSize: UIDevice.isSmall() || UIDevice.isPad() ? 20 : 22)
        songNameLabel.textColor = .label
        songInfoContainer.addSubview(songNameLabel)
        songNameLabel.snp.makeConstraints { make in
            make.height.equalToSuperview().multipliedBy(0.6)
            make.width.lessThanOrEqualToSuperview()
            make.centerX.top.equalToSuperview()
        }
        
        artistNameLabel.font = .boldSystemFont(ofSize: UIDevice.isSmall() || UIDevice.isPad() ? 18 : 16)
        artistNameLabel.textColor = .secondaryLabel
        songInfoContainer.addSubview(artistNameLabel)
        artistNameLabel.snp.makeConstraints { make in
            make.height.equalToSuperview().multipliedBy(0.4)
            make.width.lessThanOrEqualToSuperview()
            make.centerX.bottom.equalToSuperview()
        }
        
        //
        // Progress bar
        //
        
        progressBarContainer.snp.makeConstraints { make in
            make.height.equalTo(20)
            make.leading.trailing.equalToSuperview()
        }

        elapsedTimeLabel.textColor = .label
        elapsedTimeLabel.font = .systemFont(ofSize: 14)
        elapsedTimeLabel.textAlignment = .right
        elapsedTimeLabel.adjustsFontSizeToFitWidth = true
        elapsedTimeLabel.minimumScaleFactor = 0.5
        progressBarContainer.addSubview(elapsedTimeLabel)
        elapsedTimeLabel.snp.makeConstraints { make in
            make.width.equalTo(40)
            make.leading.centerY.equalToSuperview()
        }

        remainingTimeLabel.textColor = .label
        remainingTimeLabel.font = .systemFont(ofSize: 14)
        remainingTimeLabel.textAlignment = .left
        remainingTimeLabel.adjustsFontSizeToFitWidth = true
        remainingTimeLabel.minimumScaleFactor = 0.5
        progressBarContainer.addSubview(remainingTimeLabel)
        remainingTimeLabel.snp.makeConstraints { make in
            make.width.equalTo(40)
            make.trailing.centerY.equalToSuperview()
        }

        progressSlider.setThumbImage(UIImage(named: "controller-slider-thumb"), for: .normal)
        progressBarContainer.addSubview(progressSlider)
        progressSlider.snp.makeConstraints { make in
            make.leading.equalTo(elapsedTimeLabel.snp.trailing).offset(10)
            make.trailing.equalTo(remainingTimeLabel.snp.leading).offset(-10)
            make.centerY.equalToSuperview()
        }
        setupProgressSlider()
        
        downloadProgressView.backgroundColor = UIColor.systemGray4
        progressBarContainer.insertSubview(downloadProgressView, belowSubview: progressSlider)
        downloadProgressView.snp.makeConstraints { make in
//            make.width.equalTo(0)
            make.width.equalTo(0)
            make.leading.equalTo(progressSlider).offset(-5)
            make.top.equalTo(progressSlider).offset(-3)
            make.bottom.equalTo(progressSlider).offset(3)
        }
        
        //
        // Controls
        //
        
        controlsStack.axis = .horizontal
        controlsStack.alignment = .center
        controlsStack.distribution = .equalCentering
        controlsStack.addArrangedSubviews([quickSkipBackButton, previousButton, playPauseButton, nextButton, quickSkipForwardButton])
        controlsStack.snp.makeConstraints { make in
            make.height.equalTo(40)
            make.leading.trailing.equalToSuperview()
        }
        
        let playButtonConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .ultraLight, scale: .large)
        playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: playButtonConfig), for: .normal)
        playPauseButton.tintColor = iconDefaultColor
        playPauseButton.addClosure(for: .touchUpInside) { [unowned self] in
            if settings.isJukeboxEnabled {
                if jukebox.isPlaying {
                    jukebox.stop()
                } else {
                    jukebox.play()
                }
            } else {
                if let player = audioEngine.player, let currentSong = self.currentSong, !currentSong.isVideo {
                    // If we're already playing, toggle the player state
                    player.playPause()
                } else {
                    // If we haven't started the song yet, start the player
                    playQueue.playCurrentSong()
                }
            }
        }
        
        let previousButtonConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .ultraLight, scale: .large)
        previousButton.setImage(UIImage(systemName: "backward.end.fill", withConfiguration: previousButtonConfig), for: .normal)
        previousButton.tintColor = iconDefaultColor
        previousButton.addClosure(for: .touchUpInside) { [unowned self] in
            if let player = audioEngine.player, player.progress > 10.0 {
                // If we're more than 10 seconds into the song, restart it
                playQueue.playCurrentSong()
            } else {
                // Otherwise, go to the previous song
                playQueue.playPrevSong()
            }
        }
        
        let nextButtonConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .ultraLight, scale: .large)
        nextButton.setImage(UIImage(systemName: "forward.end.fill", withConfiguration: nextButtonConfig), for: .normal)
        nextButton.tintColor = iconDefaultColor
        nextButton.addClosure(for: .touchUpInside) { [unowned self] in
            playQueue.playNextSong()
        }

        let quickSkipBackButtonConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .light, scale: .large)
        quickSkipBackButton.setBackgroundImage(UIImage(systemName: "gobackward", withConfiguration: quickSkipBackButtonConfig), for: .normal)
        quickSkipBackButton.tintColor = iconDefaultColor
        quickSkipBackButton.setTitleColor(iconDefaultColor, for: .normal)
        quickSkipBackButton.titleLabel?.font = .systemFont(ofSize: 10)
        quickSkipBackButton.addClosure(for: .touchUpInside) { [unowned self] in
            let value = progressSlider.value - Float(settings.quickSkipNumberOfSeconds);
            progressSlider.value = value > 0.0 ? value : 0.0;
            seekedAction()
            Flurry.logEvent("QuickSkip")
        }
        
        let quickSkipForwardButtonConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .light, scale: .large)
        quickSkipForwardButton.setBackgroundImage(UIImage(systemName: "goforward", withConfiguration: quickSkipForwardButtonConfig), for: .normal)
        quickSkipForwardButton.tintColor = iconDefaultColor
        quickSkipForwardButton.setTitleColor(iconDefaultColor, for: .normal)
        quickSkipForwardButton.titleLabel?.font = .systemFont(ofSize: 10)
        quickSkipForwardButton.addClosure(for: .touchUpInside) { [unowned self] in
            let value = progressSlider.value + Float(settings.quickSkipNumberOfSeconds)
            if value >= progressSlider.maximumValue {
                playQueue.playNextSong()
            } else {
                progressSlider.value = value
                seekedAction()
                Flurry.logEvent("QuickSkip")
            }
        }
        
        updateQuickSkipButtons()
        
        //
        // More Controls
        //
        
        moreControlsStack.axis = .horizontal
        moreControlsStack.alignment = .center
        moreControlsStack.distribution = .equalCentering
        moreControlsStack.addArrangedSubviews([repeatButton, bookmarksButton, equalizerButton, shuffleButton])
        moreControlsStack.snp.makeConstraints { make in
            make.height.equalTo(40)
            make.leading.trailing.equalToSuperview()
        }
        
        repeatButton.addClosure(for: .touchUpInside) { [unowned self] in
            switch playQueue.repeatMode {
            case .none: playQueue.repeatMode = .one
            case .one: playQueue.repeatMode = .all
            case .all: playQueue.repeatMode = .none
            }
            self.updateRepeatButtonIcon()
        }
        updateRepeatButtonIcon()
        
        bookmarksButton.addClosure(for: .touchUpInside) { [unowned self] in
            let position = UInt(self.progressSlider.value);
            let bytePosition = UInt(audioEngine.player?.currentByteOffset ?? 0);
            let song = self.currentSong
            let alert = UIAlertController(title: "Create Bookmark", message: nil, preferredStyle: .alert)
            alert.addTextField { textField in
                textField.placeholder = "Bookmark name"
            }
            alert.addAction(title: "Save", style: .default) { action in
                guard let song = song, let name = alert.textFields?.first?.text else {
                    let errorAlert = UIAlertController(title: "Error", message: "Failed to create the bookmark, please try again.", preferredStyle: .alert)
                    errorAlert.addAction(title: "OK", style: .cancel, handler: nil)
                    self.present(errorAlert, animated: true, completion: nil)
                    return
                }
                
                ISMSBookmarkDAO.createBookmark(for: song, name: name, bookmarkPosition: position, bytePosition: bytePosition)
                self.updateBookmarkButton()
            }
            alert.addCancelAction()
            self.present(alert, animated: true, completion: nil)
        }
        updateBookmarkButton()
        
        let equalizerButtonConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular, scale: .large)
        equalizerButton.setImage(UIImage(systemName: "slider.vertical.3", withConfiguration: equalizerButtonConfig), for: .normal)
        equalizerButton.addClosure(for: .touchUpInside) { [unowned self] in
            let controller = EqualizerViewController(nibName: "EqualizerViewController", bundle: nil)
            if UIDevice.isPad() {
                self.present(controller, animated: true, completion: nil)
            } else {
                self.navigationController?.pushViewController(controller, animated: true)
            }
        }
        updateEqualizerButton()
        
        let shuffleButtonConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .ultraLight, scale: .large)
        shuffleButton.setImage(UIImage(systemName: "shuffle", withConfiguration: shuffleButtonConfig), for: .normal)
        shuffleButton.addClosure(for: .touchUpInside) { [unowned self] in
            let message = playQueue.isShuffle ? "Unshuffling" : "Shuffling"
            HUD.show(message: message)
            DispatchQueue.userInitiated.async {
                playQueue.shuffleToggle()
                DispatchQueue.main.async {
                    self.updateShuffleButtonIcon()
                }
            }
        }
        updateShuffleButtonIcon()
        
        //
        // Jukebox
        //
        
        jukeboxVolumeContainer.snp.makeConstraints { make in
            make.height.equalTo(20)
        }
        
        jukeboxVolumeSlider.setThumbImage(UIImage(named: "controller-slider-thumb"), for: .normal)
        jukeboxVolumeSlider.minimumValue = 0.0
        jukeboxVolumeSlider.maximumValue = 1.0
        jukeboxVolumeSlider.isContinuous = false
        jukeboxVolumeSlider.addClosure(for: .valueChanged) { [unowned self] in
            jukebox.setVolume(level: self.jukeboxVolumeSlider.value)
        }
        jukeboxVolumeContainer.addSubview(jukeboxVolumeSlider)
        jukeboxVolumeSlider.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
        }
        updateJukeboxControls()
        
//        verticalStackContainer.backgroundColor = .white
//        verticalStack.backgroundColor = .gray
//        songInfoContainer.backgroundColor = .red
//        progressBarContainer.backgroundColor = .blue
//        controlsStack.backgroundColor = .red
//        moreControlsStack.backgroundColor = .blue
//        jukeboxVolumeContainer.backgroundColor = .red
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        equalizerButton.isHidden = UIApplication.orientation.isLandscape
        updateSongInfo()
        startUpdatingSlider()
        startUpdatingDownloadProgress()
        updateJukeboxControls()
        updateEqualizerButton()
        registerForNotifications()
        
        if settings.isJukeboxEnabled {
            jukebox.getInfo()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopUpdatingSlider()
        stopUpdatingDownloadProgress()
        unregisterForNotifications()
    }
    
    private func registerForNotifications() {
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(updateSongInfo), name: Notifications.jukeboxSongInfo)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(updateSongInfo), name: Notifications.currentPlaylistIndexChanged)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(updateSongInfo), name: Notifications.serverSwitched)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(updateSongInfo), name: Notifications.currentPlaylistShuffleToggled)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(updateSongInfo), name: Notifications.showPlayer)
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(updateJukeboxControls), name: Notifications.jukeboxSongInfo)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(updateJukeboxControls), name: Notifications.jukeboxDisabled)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(updateJukeboxControls), name: Notifications.jukeboxEnabled)
        
        if UIDevice.isPad() {
            NotificationCenter.addObserverOnMainThread(self, selector: #selector(updateQuickSkipButtons), name: Notifications.quickSkipSecondsSettingChanged)
        }
        
        notificationObservers.append(NotificationCenter.addObserverOnMainThread(name: Notifications.songPlaybackEnded) { [unowned self] _ in
            let playButtonConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .ultraLight, scale: .large)
            self.playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: playButtonConfig), for: .normal)
            self.playPauseButton.tintColor = self.iconDefaultColor
        })
        notificationObservers.append(NotificationCenter.addObserverOnMainThread(name: Notifications.songPlaybackPaused, object: nil) { [unowned self] _ in
            let playButtonConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .ultraLight, scale: .large)
            self.playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: playButtonConfig), for: .normal)
            self.playPauseButton.tintColor = self.iconDefaultColor
        })
        notificationObservers.append(NotificationCenter.addObserverOnMainThread(name: Notifications.songPlaybackStarted, object: nil) { [unowned self] _ in
            let playButtonConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .ultraLight, scale: .large)
            self.playPauseButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: playButtonConfig), for: .normal)
            self.playPauseButton.tintColor = self.iconDefaultColor
        })
        
        notificationObservers.append(NotificationCenter.addObserverOnMainThread(name: Notifications.currentPlaylistShuffleToggled) { [unowned self] _ in
            self.updateShuffleButtonIcon()
            self.updateSongInfo()
            HUD.hide()
        })
    }
    
    private func unregisterForNotifications() {
        NotificationCenter.removeObserverOnMainThread(self)
        for observer in notificationObservers {
            NotificationCenter.removeObserverOnMainThread(observer)
        }
    }
    
    deinit {
        unregisterForNotifications()
    }
    
    private func startUpdatingSlider() {
        guard progressDisplayLink == nil else {
            progressDisplayLink?.isPaused = false
            return
        }
        
        progressDisplayLink = CADisplayLink(target: self, selector: #selector(updateSlider))
        progressDisplayLink?.isPaused = false
        progressDisplayLink?.add(to: .main, forMode: .default)
    }
    
    private func stopUpdatingSlider() {
        guard progressDisplayLink != nil else { return }
        
        progressDisplayLink?.isPaused = true
        progressDisplayLink?.remove(from: .main, forMode: .default)
        progressDisplayLink = nil
    }
    
    private func setupProgressSlider() {
        // Started seeking
        progressSlider.addClosure(for: .touchDown) { [unowned self] in
            self.progressDisplayLink?.isPaused = true
        }

        // End Seeking
        progressSlider.addTarget(self, action: #selector(seekedAction), for: .touchUpInside)
        progressSlider.addTarget(self, action: #selector(seekedAction), for: .touchUpOutside)
        progressSlider.addTarget(self, action: #selector(seekedAction), for: .touchCancel)
    }
    
    @objc private func seekedAction() {
        guard let currentSong = currentSong, let player = audioEngine.player else {
            progressDisplayLink?.isPaused = false
            return
        }
        
        lastSeekTime = Date()
        
        // TOOD: Why is this multipled by 128?
        let byteOffset = BassWrapper.estimateBitrate(player.currentStream) * 128 * UInt(progressSlider.value)
        let secondsOffset = progressSlider.value
        if currentSong.isTempCached {
            player.stop()
            
            audioEngine.startByteOffset = byteOffset
            audioEngine.startSecondsOffset = UInt(secondsOffset)
            
            streamManager.removeStream(at: 0)
            streamManager.queueStream(for: currentSong, byteOffset: UInt64(byteOffset), secondsOffset: Double(secondsOffset), at: 0, isTempCache: true, isStartDownload: true)
            if streamManager.handlerStack.count > 1 {
                if let handler = streamManager.handlerStack.firstObject as? ISMSStreamHandler {
                    handler.start()
                }
            }
            progressDisplayLink?.isPaused = false
        } else {
            if currentSong.isFullyCached || byteOffset < currentSong.localFileSize {
                player.seekToPosition(inSeconds: Double(progressSlider.value), fadeVolume: true)
                progressDisplayLink?.isPaused = false
            } else {
                let message = "You are trying to skip further than the song has cached. You can do this, but the song won't be cached. Or you can wait a little bit for the cache to catch up."
                let alert = UIAlertController(title: "Past Cache Point", message: message, preferredStyle: .alert)
                alert.addAction(title: "OK", style: .default) { _ in
                    player.stop()
                    self.audioEngine.startByteOffset = byteOffset
                    self.audioEngine.startSecondsOffset = UInt(self.progressSlider.value)
                    
                    self.streamManager.removeStream(at: 0)
                    self.streamManager.queueStream(for: currentSong, byteOffset: UInt64(byteOffset), secondsOffset: Double(self.progressSlider.value), at: 0, isTempCache: true, isStartDownload: true)
                    if self.streamManager.handlerStack.count > 1 {
                        if let handler = self.streamManager.handlerStack.firstObject as? ISMSStreamHandler {
                            handler.start()
                        }
                    }
                    self.progressDisplayLink?.isPaused = false
                }
                alert.addAction(title: "Wait", style: .cancel) { _ in
                    self.progressDisplayLink?.isPaused = false
                }
            }
        }
    }
    
    @objc private func updateSlider() {
        guard let currentSong = currentSong, let player = audioEngine.player, let progressDisplayLink = progressDisplayLink else { return }
        
        // Prevent temporary movement after seeking temp cached song
        if currentSong.isTempCached && Date().timeIntervalSince(lastSeekTime) < 5.0 && player.progress == 0.0 {
            return
        }
        
        let duration = Double(currentSong.duration)
        if settings.isJukeboxEnabled {
            elapsedTimeLabel.text = NSString.formatTime(0)
            remainingTimeLabel.text = "-\(NSString.formatTime(duration) ?? "0:00")"
            progressSlider.value = 0.0;
        } else {
            elapsedTimeLabel.text = NSString.formatTime(player.progress)
            remainingTimeLabel.text = "-\(NSString.formatTime(duration - player.progress) ?? "0:00")"
            
            // Only animate when it's moving forward
            let value = Float(player.progress)
            if value < progressSlider.value {
                progressSlider.value = value
            } else {
                let actualFramesPerSecond = 1 / (progressDisplayLink.targetTimestamp - progressDisplayLink.timestamp)
                UIView.animate(withDuration: progressDisplayLink.duration * actualFramesPerSecond) {
                    self.progressSlider.setValue(value, animated: true)
                }
            }
        }
    }
    
    @objc private func updateSongInfo() {
        guard let song = playQueue.currentSong else {
            currentSong = nil
            coverArtPageControl.coverArtId = nil
            coverArtPageControl.coverArtImage = UIImage(named: "default-album-art")
            songNameLabel.text = nil
            artistNameLabel.text = nil
            progressSlider.value = 0
            downloadProgressView.isHidden = true
            updateBookmarkButton()
            updateSlider()
            return
        }
        
        currentSong = song
        coverArtPageControl.coverArtId = song.coverArtId
        songNameLabel.text = song.title
        artistNameLabel.text = song.tagArtistName
        progressSlider.maximumValue = Float(song.duration)
        updateDownloadProgress(animated: false)
        updateBookmarkButton()
        updateSlider()
    }
    
    private var previousDownloadProgress: Float = 0.0;
    private func updateDownloadProgress(animated: Bool) {
        guard let currentSong = currentSong, !currentSong.isTempCached else {
            downloadProgressView.isHidden = true
            return
        }
        
        downloadProgressView.isHidden = settings.isJukeboxEnabled
        
        let width = currentSong.downloadProgress == 0 ? 0 : self.progressSlider.frame.width + 6
        guard width != self.downloadProgressView.frame.width else {
            return
        }
        
        func updateConstraints() {
            do {
                try ObjC.perform {
                    self.downloadProgressView.snp.updateConstraints { make in
                        do {
                            try ObjC.perform {
                                make.width.equalTo(width)
                            }
                        } catch {
                            DDLogError("[PlayerViewController] Failed to update constraints for download progress: \(error)")
                        }
                    }
                    self.downloadProgressView.superview?.layoutIfNeeded()
                }
            } catch {
                DDLogError("[PlayerViewController] Failed to update constraints for download progress: \(error)")
            }
        }
        
        // Set the width based on the download progress + leading/trailing offset size
        if animated && currentSong.downloadProgress > previousDownloadProgress {
            // If it's longer, animate it
            UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseOut, animations: updateConstraints, completion: nil)
        } else {
            // If it's shorter, it's probably starting a new song so don't animate
            updateConstraints()
        }
        
        previousDownloadProgress = currentSong.downloadProgress
    }
    
    @objc private func startUpdatingDownloadProgress() {
        stopUpdatingDownloadProgress()
        updateDownloadProgress(animated: true)
        perform(#selector(startUpdatingDownloadProgress), with: nil, afterDelay: 0.2)
    }
    
    private func stopUpdatingDownloadProgress() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(startUpdatingDownloadProgress), object: nil)
    }
    
    @objc private func showCurrentPlaylist() {
        let controller = CustomUINavigationController(rootViewController: PlayQueueViewController())
        present(controller, animated: true, completion: nil)
    }
    
    private func updateRepeatButtonIcon() {
        let imageName: String
        switch playQueue.repeatMode {
        case .none: imageName = "repeat"
        case .one: imageName = "repeat.1"
        case .all: imageName = "repeat"
        }
        
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .ultraLight, scale: .large)
        repeatButton.setImage(UIImage(systemName: imageName, withConfiguration: config), for: .normal)
        repeatButton.tintColor = playQueue.repeatMode == .none ? iconDefaultColor : iconActivatedColor
    }
    
    private func updateShuffleButtonIcon() {
        shuffleButton.tintColor = playQueue.isShuffle ? iconActivatedColor : iconDefaultColor
    }
    
    @objc private func updateJukeboxControls() {
        let jukeboxEnabled = settings.isJukeboxEnabled
        equalizerButton.isHidden = jukeboxEnabled
//        view.backgroundColor = jukeboxEnabled ? viewObjects.jukeboxColor : Colors.background
        
        let playButtonConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .ultraLight, scale: .large)
        self.playPauseButton.tintColor = self.iconDefaultColor
        if jukeboxEnabled {
            if jukebox.isPlaying {
                self.playPauseButton.setImage(UIImage(systemName: "stop.fill", withConfiguration: playButtonConfig), for: .normal)
            } else {
                self.playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: playButtonConfig), for: .normal)
            }
        } else {
            if audioEngine.player?.isPlaying ?? false {
                self.playPauseButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: playButtonConfig), for: .normal)
            } else {
                self.playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: playButtonConfig), for: .normal)
            }
        }
        
        if jukeboxEnabled {
            // Update the jukebox volume slider position
            jukeboxVolumeSlider.value = Float(jukebox.gain)
            
            // Add the volume control if needed
            if jukeboxVolumeContainer.superview == nil {
                verticalStack.addArrangedSubview(jukeboxVolumeContainer)
            }
        } else if !jukeboxEnabled && jukeboxVolumeContainer.superview != nil {
            // Remove the volume control
            verticalStack.removeArrangedSubview(jukeboxVolumeContainer)
            jukeboxVolumeContainer.removeFromSuperview()
        }
        
        // Enable/disable UI
        quickSkipBackButton.isHidden = jukeboxEnabled
        quickSkipForwardButton.isHidden = jukeboxEnabled
        progressSlider.isEnabled = !jukeboxEnabled
        progressSlider.alpha = jukeboxEnabled ? 0.5 : 1.0
        downloadProgressView.isHidden = jukeboxEnabled
        title = jukeboxEnabled ? "Jukebox Mode" : ""
        if UIDevice.isPad() {
            view.backgroundColor = jukeboxEnabled ? Colors.jukeboxWindowColor.withAlphaComponent(0.5) : Colors.background
        }
    }
    
    private func updateEqualizerButton() {
        equalizerButton.tintColor = settings.isEqualizerOn ? iconActivatedColor : iconDefaultColor
    }
    
    private func updateBookmarkButton() {
        // TODO: implement this
//        var bookmarkCount: Int32 = 0
//        if let songId = self.currentSong?.id {
//            DatabaseOld.shared().bookmarksDbQueue?.inDatabase { db in
//                do {
//                    let result = try db.executeQuery("SELECT COUNT(*) FROM bookmarks WHERE songId = ?", values: [songId])
//                    if result.next() {
//                        bookmarkCount = result.int(forColumnIndex: 0)
//                    }
//                    result.close()
//                } catch {
//                    DDLogError("[PlayerViewController] Failed to query the bookmark count: \(error)")
//                }
//            }
//        }
//
//        let imageName = bookmarkCount > 0 ? "bookmark.fill" : "bookmark"
//        let tintColor = bookmarkCount > 0 ? iconActivatedColor : iconDefaultColor
//        let config = UIImage.SymbolConfiguration(pointSize: 21, weight: .light, scale: .large)
//        bookmarksButton.setImage(UIImage(systemName: imageName, withConfiguration: config), for: .normal)
//        bookmarksButton.tintColor = tintColor
    }
    
    @objc private func updateQuickSkipButtons() {
        let seconds = settings.quickSkipNumberOfSeconds
        let quickSkipTitle = seconds < 60 ? "\(seconds)s" : "\(seconds/60)m"
        quickSkipBackButton.setTitle(quickSkipTitle, for: .normal)
        quickSkipForwardButton.setTitle(quickSkipTitle, for: .normal)
    }
}

