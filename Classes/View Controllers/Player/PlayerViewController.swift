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

private let controlStackHeight: CGFloat = UIDevice.isSmall ? 34 : 44
private let controlButtonWidth: CGFloat = UIDevice.isSmall ? 40 : 60
private let pointSize: CGFloat = UIDevice.isSmall ? 20 : 24
private let ultralightConfig = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .ultraLight, scale: .large)
private let lightConfig = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .light, scale: .large)
private let regularConfig = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular, scale: .large)

// TODO: Add bitrate and file type labels
final class PlayerViewController: UIViewController {
    @Injected private var store: Store
    @Injected private var settings: Settings
    @Injected private var jukebox: Jukebox
    @Injected private var player: BassPlayer
    @Injected private var playQueue: PlayQueue
    @Injected private var streamManager: StreamManager
    @Injected private var analytics: Analytics
    
    override var prefersStatusBarHidden: Bool { true }
    
    var currentSong: Song?
    
    private var notificationObservers = [NSObjectProtocol]()
    
    private let backgroundView = UIView()
    
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
        if UIApplication.orientation.isPortrait || UIDevice.isPad {
            coverArtPageControl.view.snp.remakeConstraints { make in
                let offset = UIDevice.isSmall ? 10 : 20
                make.height.equalTo(coverArtPageControl.view.snp.width).offset(offset)
                make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(offset)
                make.leading.equalToSuperview().offset(offset)
                make.trailing.equalToSuperview().offset(-offset)
            }
            
            verticalStackContainer.snp.remakeConstraints { make in
                if UIDevice.isPad {
                    make.width.equalTo(coverArtPageControl.view)
                } else {
                    make.width.equalTo(coverArtPageControl.view).multipliedBy(0.9)
                }
                make.centerX.equalTo(coverArtPageControl.view)
                make.top.equalTo(coverArtPageControl.view.snp.bottom)
                make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            }
            
            verticalStack.snp.remakeConstraints { make in
                make.leading.trailing.equalToSuperview()
                if UIDevice.isSmall || UIDevice.isPad {
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
                make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(20)
                make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
                if UIDevice.isSmall {
                    make.leading.equalToSuperview().offset(20)
                } else {
                    make.centerX.equalToSuperview().multipliedBy(0.5)
                }
            }
            
            verticalStackContainer.snp.remakeConstraints { make in
                make.leading.equalTo(coverArtPageControl.view.snp.trailing).offset(40)
                make.trailing.equalToSuperview().offset(-40)
                make.top.equalToSuperview()
                make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
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
        
        if UIDevice.isPad {
            view.overrideUserInterfaceStyle = .dark
        }
        view.backgroundColor = Colors.background
        title = "Player"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(image:  UIImage(systemName: "list.number"), style: .plain, target: self, action: #selector(showCurrentPlaylist))
        
        backgroundView.backgroundColor = Colors.background
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
        
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
            make.height.equalTo(UIDevice.isSmall || UIDevice.isPad ? 50 : 60)
            make.centerX.equalToSuperview()
        }
        
        songNameLabel.font = .boldSystemFont(ofSize: UIDevice.isSmall || UIDevice.isPad ? 20 : 22)
        songNameLabel.textColor = .label
        songInfoContainer.addSubview(songNameLabel)
        songNameLabel.snp.makeConstraints { make in
            make.height.equalToSuperview().multipliedBy(0.6)
            make.width.lessThanOrEqualToSuperview()
            make.centerX.top.equalToSuperview()
        }
        
        artistNameLabel.font = .boldSystemFont(ofSize: UIDevice.isSmall || UIDevice.isPad ? 18 : 16)
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
            make.height.equalTo(UIDevice.isSmall ? 20 : 40)
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

        progressSlider.setThumbImage(UIImage(named: "controller-slider-thumb")?.withTintColor(.label), for: .normal)
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
            make.height.equalTo(controlStackHeight)
            make.leading.trailing.equalToSuperview()
        }
        
        playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: ultralightConfig), for: .normal)
        playPauseButton.tintColor = Colors.playerButton
        playPauseButton.addClosure(for: .touchUpInside) { [unowned self] in
            if settings.isJukeboxEnabled {
                if jukebox.isPlaying {
                    jukebox.stop()
                } else {
                    jukebox.play()
                }
            } else {
                if let currentSong = self.currentSong, !currentSong.isVideo {
                    // If we're already playing, toggle the player state
                    player.playPause()
                } else {
                    // If we haven't started the song yet, start the player
                    playQueue.playCurrentSong()
                }
            }
        }
        
        previousButton.setImage(UIImage(systemName: "backward.end.fill", withConfiguration: ultralightConfig), for: .normal)
        previousButton.tintColor = Colors.playerButton
        previousButton.addClosure(for: .touchUpInside) { [unowned self] in
            if player.progress > 10.0 {
                // If we're more than 10 seconds into the song, restart it
                playQueue.playCurrentSong()
            } else {
                // Otherwise, go to the previous song
                playQueue.playPrevSong()
            }
        }
        
        nextButton.setImage(UIImage(systemName: "forward.end.fill", withConfiguration: ultralightConfig), for: .normal)
        nextButton.tintColor = Colors.playerButton
        nextButton.addClosure(for: .touchUpInside) { [unowned self] in
            playQueue.playNextSong()
        }

        quickSkipBackButton.setBackgroundImage(UIImage(systemName: "gobackward", withConfiguration: lightConfig), for: .normal)
        quickSkipBackButton.tintColor = Colors.playerButton
        quickSkipBackButton.setTitleColor(Colors.playerButton, for: .normal)
        quickSkipBackButton.titleLabel?.font = .systemFont(ofSize: UIDevice.isSmall ? 7 : 10)
        quickSkipBackButton.addClosure(for: .touchUpInside) { [unowned self] in
            let value = progressSlider.value - Float(settings.quickSkipNumberOfSeconds);
            progressSlider.value = value > 0.0 ? value : 0.0;
            seekedAction()
            analytics.log(event: .quickSkip)
        }
        
        quickSkipForwardButton.setBackgroundImage(UIImage(systemName: "goforward", withConfiguration: lightConfig), for: .normal)
        quickSkipForwardButton.tintColor = Colors.playerButton
        quickSkipForwardButton.setTitleColor(Colors.playerButton, for: .normal)
        quickSkipForwardButton.titleLabel?.font = .systemFont(ofSize: UIDevice.isSmall ? 7 : 10)
        quickSkipForwardButton.addClosure(for: .touchUpInside) { [unowned self] in
            let value = progressSlider.value + Float(settings.quickSkipNumberOfSeconds)
            if value >= progressSlider.maximumValue {
                playQueue.playNextSong()
            } else {
                progressSlider.value = value
                seekedAction()
            }
            analytics.log(event: .quickSkip)
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
            make.height.equalTo(controlStackHeight)
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
            let songIndex = playQueue.currentIndex
            let offsetInSeconds = Double(self.progressSlider.value)
            let offsetInBytes = player.currentByteOffset
            
            let alert = UIAlertController(title: "Create Bookmark", message: nil, preferredStyle: .alert)
            alert.addTextField { textField in
                textField.placeholder = "Bookmark name"
            }
            alert.addAction(title: "Save", style: .default) { [unowned self] action in
                var success = false
                if let name = alert.textFields?.first?.text {
                    success = store.addBookmark(name: name, songIndex: songIndex, offsetInSeconds: offsetInSeconds, offsetInBytes: offsetInBytes)
                }
                
                if !success {
                    let errorAlert = UIAlertController(title: "Error", message: "Failed to create the bookmark, please try again.", preferredStyle: .alert)
                    errorAlert.addAction(title: "OK", style: .cancel, handler: nil)
                    self.present(errorAlert, animated: true, completion: nil)
                    return
                }
                
                updateBookmarkButton()
            }
            alert.addCancelAction()
            self.present(alert, animated: true, completion: nil)
        }
        updateBookmarkButton()
        
        let equalizerButtonImage: UIImage?
        if #available(iOS 14.0, *) {
            equalizerButtonImage = UIImage(systemName: "slider.vertical.3", withConfiguration: regularConfig)
        } else {
            equalizerButtonImage = UIImage(systemName: "slider.horizontal.3", withConfiguration: regularConfig)
        }
        equalizerButton.setImage(equalizerButtonImage, for: .normal)
        equalizerButton.addClosure(for: .touchUpInside) { [unowned self] in
            let controller = EqualizerViewController(nibName: "EqualizerViewController", bundle: nil)
            if UIDevice.isPad {
                self.present(controller, animated: true, completion: nil)
            } else {
                self.navigationController?.pushViewController(controller, animated: true)
            }
        }
        updateEqualizerButton()
        
        shuffleButton.setImage(UIImage(systemName: "shuffle", withConfiguration: ultralightConfig), for: .normal)
        shuffleButton.addClosure(for: .touchUpInside) { [unowned self] in
            let message = playQueue.isShuffle ? "Unshuffling" : "Shuffling"
            HUD.show(message: message)
            DispatchQueue.userInitiated.async {
                defer { HUD.hide() }
                playQueue.shuffleToggle()
                DispatchQueue.main.async {
                    self.updateShuffleButtonIcon()
                }
            }
        }
        updateShuffleButtonIcon()
        
        // Adjust button sizes and image scaling modes
        for arrangedSubview in (controlsStack.arrangedSubviews + moreControlsStack.arrangedSubviews) {
            // Set the size and content mode on buttons that have background images
            if let button = arrangedSubview as? UIButton, button.backgroundImage(for: .normal) != nil {
                // Force layout so the button creates it's background view
                button.layoutIfNeeded()
                
                if let backgroundImageView = button.subviews.first as? UIImageView {
                    // Set the content mode on the background image view
                    backgroundImageView.contentMode = .scaleAspectFit
                    
                    // Set the size of the background image view to better match other buttons
                    backgroundImageView.snp.makeConstraints { make in
                        make.width.height.equalTo(controlStackHeight - 10)
                        make.centerX.centerY.equalToSuperview()
                    }
                }
            }
            
            // Set the size and content mode (content mode only applies to buttons with images not background images)
            arrangedSubview.contentMode = .scaleAspectFit
            arrangedSubview.snp.makeConstraints { make in
                make.width.equalTo(controlButtonWidth)
                make.height.equalTo(controlStackHeight)
            }
        }
        
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
        
        if UIDevice.isPad {
            NotificationCenter.addObserverOnMainThread(self, selector: #selector(updateQuickSkipButtons), name: Notifications.quickSkipSecondsSettingChanged)
        }
        
        notificationObservers.append(NotificationCenter.addObserverOnMainThread(name: Notifications.songPlaybackEnded) { [unowned self] _ in
            self.playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: ultralightConfig), for: .normal)
            self.playPauseButton.tintColor = Colors.playerButton
        })
        notificationObservers.append(NotificationCenter.addObserverOnMainThread(name: Notifications.songPlaybackPaused) { [unowned self] _ in
            self.playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: ultralightConfig), for: .normal)
            self.playPauseButton.tintColor = Colors.playerButton
        })
        notificationObservers.append(NotificationCenter.addObserverOnMainThread(name: Notifications.songPlaybackStarted) { [unowned self] _ in
            self.playPauseButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: ultralightConfig), for: .normal)
            self.playPauseButton.tintColor = Colors.playerButton
        })
        
        notificationObservers.append(NotificationCenter.addObserverOnMainThread(name: Notifications.currentPlaylistShuffleToggled) { [unowned self] _ in
            defer { HUD.hide() }
            self.updateShuffleButtonIcon()
            self.updateSongInfo()
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
        guard let currentSong = currentSong else {
            progressDisplayLink?.isPaused = false
            return
        }
        
        lastSeekTime = Date()
        
        // TOOD: Why is this multipled by 128?
        let estimatedKiloBitrate: Int
        if let currentStream = player.currentStream {
            estimatedKiloBitrate = Bass.estimateKiloBitrate(bassStream: currentStream)
        } else {
            estimatedKiloBitrate = currentSong.estimatedKiloBitrate
        }
        let byteOffset = estimatedKiloBitrate * 128 * Int(progressSlider.value)
        let secondsOffset = Double(progressSlider.value)
        if currentSong.isTempCached {
            player.stop()
            
            player.startByteOffset = byteOffset
            player.startSecondsOffset = secondsOffset
            
            streamManager.removeStream(index: 0)
            streamManager.queueStream(song: currentSong, byteOffset: byteOffset, secondsOffset: secondsOffset, index: 0, tempCache: true, startDownload: true)
            if let handler = streamManager.firstHandlerInQueue {
                handler.start()
            }
            progressDisplayLink?.isPaused = false
        } else {
            if currentSong.isFullyCached || byteOffset < currentSong.localFileSize {
                player.seekToPosition(seconds: Double(progressSlider.value), fadeVolume: true)
                progressDisplayLink?.isPaused = false
            } else {
                let message = "You are trying to skip further than the song has cached. You can do this, but the song won't be cached. Or you can wait a little bit for the cache to catch up."
                let alert = UIAlertController(title: "Past Cache Point", message: message, preferredStyle: .alert)
                alert.addAction(title: "OK", style: .default) { _ in
                    self.player.stop()
                    self.player.startByteOffset = byteOffset
                    self.player.startSecondsOffset = secondsOffset
                    
                    self.streamManager.removeStream(index: 0)
                    self.streamManager.queueStream(song: currentSong, byteOffset: byteOffset, secondsOffset: secondsOffset, index: 0, tempCache: true, startDownload: true)
                    if let handler = self.streamManager.firstHandlerInQueue {
                        handler.start()
                    }
                    self.progressDisplayLink?.isPaused = false
                }
                alert.addAction(title: "Wait", style: .cancel) { _ in
                    self.progressDisplayLink?.isPaused = false
                }
            }
        }
    }
    
    @objc private func updateSlider(animated: Bool = true) {
        guard let currentSong = currentSong, let progressDisplayLink = progressDisplayLink else { return }
        
        // Prevent temporary movement after seeking temp cached song
        if currentSong.isTempCached && Date().timeIntervalSince(lastSeekTime) < 5.0 && player.progress == 0.0 {
            return
        }
        
        let duration = Double(currentSong.duration)
        if settings.isJukeboxEnabled {
            elapsedTimeLabel.text = formatTime(seconds: 0)
            remainingTimeLabel.text = "-\(formatTime(seconds: duration))"
            progressSlider.value = 0.0;
        } else {
            elapsedTimeLabel.text = formatTime(seconds: player.progress)
            remainingTimeLabel.text = "-\(formatTime(seconds: duration - player.progress))"
            
            // Only animate when it's moving forward
            let value = Float(player.progress)
            if !animated || value < progressSlider.value {
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
        func enableDisableControls(enable: Bool) {
            let alpha: CGFloat = enable ? 1.0 : 0.7
            if !enable {
                coverArtPageControl.showCoverArt(animated: false)
            }
            coverArtPageControl.view.isUserInteractionEnabled = enable
            coverArtPageControl.view.alpha = alpha
            
            progressSlider.isUserInteractionEnabled = enable
            progressSlider.alpha = alpha
            let sliderTintColor: UIColor = enable ? .label : .secondaryLabel
            progressSlider.setThumbImage(UIImage(named: "controller-slider-thumb")?.withTintColor(sliderTintColor), for: .normal)
            
            for subview in (controlsStack.arrangedSubviews + moreControlsStack.arrangedSubviews) {
                subview.alpha = alpha
                if let control = subview as? UIControl {
                    control.isEnabled = enable
                }
            }
        }
        
        guard let song = playQueue.currentSong else {
            currentSong = nil
            coverArtPageControl.coverArtId = nil
            coverArtPageControl.coverArtImage = UIImage(named: "default-album-art")
            songNameLabel.text = nil
            artistNameLabel.text = nil
            elapsedTimeLabel.text = nil
            remainingTimeLabel.text = nil
            progressSlider.value = 0
            downloadProgressView.isHidden = true
            updateBookmarkButton()
            updateSlider(animated: false)
            enableDisableControls(enable: false)
            return
        }
        
        currentSong = song
        coverArtPageControl.coverArtId = song.coverArtId
        songNameLabel.text = song.title
        artistNameLabel.text = song.tagArtistName
        progressSlider.maximumValue = Float(song.duration)
        updateDownloadProgress(animated: false)
        updateBookmarkButton()
        updateSlider(animated: false)
        enableDisableControls(enable: true)

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
        
        repeatButton.setImage(UIImage(systemName: imageName, withConfiguration: ultralightConfig), for: .normal)
        repeatButton.tintColor = playQueue.repeatMode == .none ? Colors.playerButton : Colors.playerButtonActivated
    }
    
    private func updateShuffleButtonIcon() {
        shuffleButton.tintColor = playQueue.isShuffle ? Colors.playerButtonActivated : Colors.playerButton
    }
    
    @objc private func updateJukeboxControls() {
        let jukeboxEnabled = settings.isJukeboxEnabled
        equalizerButton.isHidden = jukeboxEnabled
        
        self.playPauseButton.tintColor = Colors.playerButton
        if jukeboxEnabled {
            if jukebox.isPlaying {
                self.playPauseButton.setImage(UIImage(systemName: "stop.fill", withConfiguration: ultralightConfig), for: .normal)
            } else {
                self.playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: ultralightConfig), for: .normal)
            }
        } else {
            if player.isPlaying {
                self.playPauseButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: ultralightConfig), for: .normal)
            } else {
                self.playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: ultralightConfig), for: .normal)
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
        view.backgroundColor = jukeboxEnabled ? Colors.jukeboxWindow : Colors.background
        if UIDevice.isPad {
            backgroundView.backgroundColor = view.backgroundColor
        }
    }
    
    private func updateEqualizerButton() {
        equalizerButton.tintColor = settings.isEqualizerOn ? Colors.playerButtonActivated : Colors.playerButton
    }
    
    private func updateBookmarkButton() {
        var bookmarksCount = 0
        if let song = currentSong, let count = store.bookmarksCount(song: song) {
            bookmarksCount = count
        }
        
        let imageName = bookmarksCount > 0 ? "bookmark.fill" : "bookmark"
        let tintColor = bookmarksCount > 0 ? Colors.playerButtonActivated : Colors.playerButton
        let config = UIImage.SymbolConfiguration(pointSize: UIDevice.isSmall ? 18 : 21, weight: .light, scale: .large)
        bookmarksButton.setImage(UIImage(systemName: imageName, withConfiguration: config), for: .normal)
        bookmarksButton.tintColor = tintColor
    }
    
    @objc private func updateQuickSkipButtons() {
        let seconds = settings.quickSkipNumberOfSeconds
        let quickSkipTitle = seconds < 60 ? "\(seconds)s" : "\(seconds/60)m"
        quickSkipBackButton.setTitle(quickSkipTitle, for: .normal)
        quickSkipForwardButton.setTitle(quickSkipTitle, for: .normal)
    }
}

