//
//  HomeViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 11/14/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import CocoaLumberjackSwift
import Resolver

final class HomeViewController: UIViewController {
    @Injected private var store: Store
    @Injected private var settings: Settings
    @Injected private var player: BassPlayer
    @Injected private var jukebox: Jukebox
    @Injected private var playQueue: PlayQueue
    @Injected private var analytics: Analytics
    
    var serverId: Int { Settings.shared().currentServerId }
    
    private var quickAlbumsLoader: QuickAlbumsLoader?
    private var serverShuffleLoader: ServerShuffleLoader?
    private var searchLoader: SearchLoader?
    
    private let searchBarContainer = UIView()
    private let searchBar = UISearchBar()
    private let searchSegmentContainer = UIView()
    private let searchSegment = UISegmentedControl()
    private let searchOverlay = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let dismissButton = UIButton(type: .custom)
    
    private let songInfoButton = HomeSongInfoButton()
    private var songInfoButtonAlpha: CGFloat = 1
    
    private let topRowStack = UIStackView()
    private let bottomRowStack = UIStackView()
    private let verticalStack = UIStackView()
    
    private let quickAlbumsButton = HomeViewButton(icon: UIImage(named: "home-quick"), title: "Quick\nAlbums")
    private let serverShuffleButton = HomeViewButton(icon: UIImage(named: "home-shuffle"), title: "Server\nShuffle")
    private let jukeboxButton = HomeViewButton(icon: UIImage(named: "home-jukebox-off"), title: "Jukebox\nMode is OFF")
    private let settingsButton = HomeViewButton(icon: UIImage(named: "home-settings"), title: "App\nSettings")
    private let nowPlayingButton = HomeViewButton(icon: UIImage(systemName: "headphones", withConfiguration: UIImage.SymbolConfiguration(pointSize: 42, weight: .light, scale: .large)), title: "Now\nPlaying")
    private let chatButton = HomeViewButton(icon: UIImage(named: "home-chat"), title: "Server\nChat")
    private var buttons: [HomeViewButton] {
        return [quickAlbumsButton, serverShuffleButton, jukeboxButton, settingsButton, nowPlayingButton, chatButton]
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard verticalStack.superview != nil else { return }
        view.setNeedsUpdateConstraints()
    }
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        let iphoneOffset = UIDevice.isSmall ? -10 : 20
        if UIApplication.orientation.isPortrait || UIDevice.isPad {
            for button in buttons {
                button.showLabel()
            }
            songInfoButton.alpha = songInfoButtonAlpha
            searchSegment.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(13)
                make.trailing.equalToSuperview().offset(-13)
                make.top.equalToSuperview().offset(5)
                make.bottom.equalToSuperview().offset(-10)
            }
            verticalStack.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(UIDevice.isPad ? 50 : iphoneOffset)
                make.trailing.equalToSuperview().offset(UIDevice.isPad ? -50 : -iphoneOffset)
                make.centerY.equalToSuperview().offset(15)
                make.height.equalToSuperview().multipliedBy(UIDevice.isPad ? 0.50 : 0.75)
            }
        } else {
            for button in buttons {
                button.hideLabel()
            }
            songInfoButton.alpha = 0
            searchSegment.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(52)
                make.trailing.equalToSuperview().offset(-52)
                make.top.equalToSuperview().offset(5)
                make.bottom.equalToSuperview().offset(-10)
            }
            verticalStack.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(iphoneOffset)
                make.trailing.equalToSuperview().offset(-iphoneOffset)
                make.centerY.equalToSuperview().offset(15)
                make.height.equalToSuperview().multipliedBy(0.60)
            }
        }
    }
    
    private func registerNotifications() {
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(jukeboxOff), name: Notifications.jukeboxDisabled)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(initSongInfo), name: Notifications.songPlaybackStarted)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(initSongInfo), name: Notifications.serverSwitched)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(addURLRefBackButton), name: UIApplication.didBecomeActiveNotification)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(didEnterOnlineMode), name: Notifications.didEnterOnlineMode)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(didEnterOfflineMode), name: Notifications.didEnterOfflineMode)
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Colors.background
        title = "Home"
        
        registerNotifications()
        
        quickAlbumsButton.setAction { [unowned self] in
            let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            sheet.addAction(title: "Recently Played", style: .default) { action in
                self.loadQuickAlbums(modifier: "recent", title: action.title ?? "")
            }
            sheet.addAction(title: "Frequently Played", style: .default) { action in
                self.loadQuickAlbums(modifier: "frequent", title: action.title ?? "")
            }
            sheet.addAction(title: "Recently Added", style: .default) { action in
                self.loadQuickAlbums(modifier: "newest", title: action.title ?? "")
            }
            sheet.addAction(title: "Random Albums", style: .default) { action in
                self.loadQuickAlbums(modifier: "random", title: action.title ?? "")
            }
            sheet.addCancelAction()
            if let popoverPresentationController = sheet.popoverPresentationController {
                // Fix exception on iPad
                popoverPresentationController.sourceView = self.quickAlbumsButton
                popoverPresentationController.sourceRect = self.quickAlbumsButton.bounds
            }
            present(sheet, animated: true, completion: nil)
        }
        
        serverShuffleButton.setAction { [unowned self] in
            let mediaFolders = store.mediaFolders(serverId: serverId)
            if mediaFolders.count > 0 {
                // 2 media folders means the "All Media Folders" option plus one folder aka only 1 actual media folder
                if mediaFolders.count == 2 {
                    performServerShuffle(mediaFolderId: MediaFolder.allFoldersId)
                } else {
                    let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                    sheet.addAction(title: "All Media Folders", style: .default) { action in
                        self.performServerShuffle(mediaFolderId: MediaFolder.allFoldersId)
                    }
                    for mediaFolder in mediaFolders {
                        if mediaFolder.id != MediaFolder.allFoldersId {
                            sheet.addAction(title: mediaFolder.name, style: .default) { action in
                                self.performServerShuffle(mediaFolderId: mediaFolder.id)
                            }
                        }
                    }
                    sheet.addCancelAction()
                    if let popoverPresentationController = sheet.popoverPresentationController {
                        // Fix exception on iPad
                        popoverPresentationController.sourceView = self.serverShuffleButton
                        popoverPresentationController.sourceRect = self.serverShuffleButton.bounds
                    }
                    present(sheet, animated: true, completion: nil)
                }
            }
        }
        
        jukeboxButton.setAction { [unowned self] in
            if settings.isJukeboxEnabled {
                self.jukeboxButton.setIcon(image: UIImage(named: "home-jukebox-off"))
                self.jukeboxButton.setTitle(title: "Jukebox\nMode is OFF")
                settings.isJukeboxEnabled = false
                NotificationCenter.postOnMainThread(name: Notifications.jukeboxDisabled)
                analytics.log(event: .jukeboxDisabled)
            } else {
                player.stop()
                self.jukeboxButton.setIcon(image: UIImage(named: "home-jukebox-on"))
                self.jukeboxButton.setTitle(title: "Jukebox\nMode is ON")
                settings.isJukeboxEnabled = true
                self.jukebox.getInfo()
                NotificationCenter.postOnMainThread(name: Notifications.jukeboxEnabled)
                analytics.log(event: .jukeboxEnabled)
            }
            self.initSongInfo()
        }
        
        topRowStack.translatesAutoresizingMaskIntoConstraints = false
        topRowStack.addArrangedSubviews([quickAlbumsButton, serverShuffleButton, jukeboxButton])
        topRowStack.axis = .horizontal
        topRowStack.distribution = .equalCentering
        
        settingsButton.setAction {
            SceneDelegate.shared.showSettings()
        }
                
        // Match the slightly different color of the other icons
        // TODO: Edit the other icon images to match the default blue color instead
        nowPlayingButton.setIconTint(color: UIColor(red: 21.0/255.0, green: 122.0/255.0, blue: 251.0/255.0, alpha: 1))
        nowPlayingButton.setAction { [unowned self] in
            navigationController?.pushViewController(NowPlayingViewController(), animated: true)
        }
        
        chatButton.setAction { [unowned self] in
            navigationController?.pushViewController(ChatViewController(), animated: true)
        }
        
        bottomRowStack.translatesAutoresizingMaskIntoConstraints = false
        bottomRowStack.addArrangedSubviews([settingsButton, nowPlayingButton, chatButton])
        bottomRowStack.axis = .horizontal
        bottomRowStack.distribution = .equalCentering

        verticalStack.translatesAutoresizingMaskIntoConstraints = false
        verticalStack.addArrangedSubviews([topRowStack, bottomRowStack])
        verticalStack.axis = .vertical
        verticalStack.distribution = .equalCentering
        view.addSubview(verticalStack)
        
        dismissButton.addTarget(searchBar, action: #selector(resignFirstResponder), for: .touchUpInside)
        
        view.addSubview(searchBarContainer)
        searchBarContainer.snp.makeConstraints { make in
            make.height.equalTo(50)
            make.leading.trailing.top.equalToSuperview()
        }
        
        searchBar.delegate = self
        searchBar.placeholder = "Server Search"
        searchBar.searchBarStyle = .minimal
        searchBarContainer.addSubview(searchBar)
        searchBar.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(5)
            make.trailing.bottom.equalToSuperview().offset(-5)
        }
        
        searchSegmentContainer.backgroundColor = Colors.background
        view.addSubview(searchSegmentContainer)
        searchSegmentContainer.snp.makeConstraints { make in
            make.height.equalTo(50)
            make.top.equalTo(searchBarContainer.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }
        
        searchSegment.insertSegment(withTitle: "Folders", at: 0, animated: false)
        searchSegment.insertSegment(withTitle: "Tags", at: 1, animated: false)
        searchSegment.selectedSegmentIndex = 0
        searchSegmentContainer.addSubview(searchSegment)
        
        if UIDevice.isPad {
            songInfoButton.isHidden = true
            songInfoButton.isUserInteractionEnabled = false
        }
        songInfoButton.translatesAutoresizingMaskIntoConstraints = false
        songInfoButton.setAction {
            NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
        }
        view.addSubview(songInfoButton)
        songInfoButton.snp.remakeConstraints { make in
            make.height.equalTo(UIDevice.isSmall ? 60 : 80)
            make.leading.equalToSuperview().offset(UIDevice.isSmall ? 20 : 35)
            make.trailing.equalToSuperview().offset(UIDevice.isSmall ? -20 : -30)
            make.centerY.equalTo(verticalStack)
        }
        
        if settings.isOfflineMode {
            didEnterOfflineMode()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addURLRefBackButton()
        
        let jukeboxImageName = settings.isJukeboxEnabled ? "home-jukebox-on" : "home-jukebox-off"
        let jukeboxTitle = "Jukebox\nMode is \(settings.isJukeboxEnabled ? "ON" : "OFF")"
        jukeboxButton.setIcon(image: UIImage(named: jukeboxImageName))
        jukeboxButton.setTitle(title: jukeboxTitle)
        
        searchSegment.alpha = 0.0
        searchSegment.isEnabled = false
        searchSegmentContainer.alpha = 0.0
        
        initSongInfo()
        
        analytics.log(event: .homeTab)
    }
    
    @objc private func addURLRefBackButton() {
        if AppDelegate.shared.referringAppUrl != nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: AppDelegate.shared, action: #selector(AppDelegate.backToReferringApp))
        }
    }
    
    @objc private func initSongInfo() {
        songInfoButton.update(song: playQueue.currentSong ?? playQueue.prevSong)
    }
    
    private func loadQuickAlbums(modifier: String, title: String) {
        HUD.show(closeHandler: cancelLoad)
        let loader = QuickAlbumsLoader(serverId: serverId, modifier: modifier)
        loader.callback = { _, _, error in
            HUD.hide()
            if let error = error {
                if self.settings.isPopupsEnabled && !error.isCanceledURLRequest {
                    let alert = UIAlertController(title: "Error", message: "There was an error grabbing the album list.\n\nError: \(error.localizedDescription)", preferredStyle: .alert)
                    alert.addAction(title: "OK", style: .cancel, handler: nil)
                    self.present(alert, animated: true, completion: nil)
                }
            } else {
                let controller = HomeAlbumViewController()
                controller.modifier = modifier
                controller.title = title
                controller.folderAlbums = loader.folderAlbums
                self.pushViewControllerCustom(controller)
            }
            self.quickAlbumsLoader = nil
        }
        quickAlbumsLoader = loader
        loader.startLoad()
    }
    
    private func performServerShuffle(mediaFolderId: Int) {
        HUD.show(closeHandler: cancelLoad)
        let loader = ServerShuffleLoader(serverId: serverId, mediaFolderId: mediaFolderId)
        loader.callback = { [unowned self] _, success, _ in
            HUD.hide()
            if success {
                playQueue.playSong(position: 0)
                NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
            } else {
                if settings.isPopupsEnabled {
                    let alert = UIAlertController(title: "Error", message: "There was an error creating the server shuffle list.\n\nThe connection could not be created", preferredStyle: .alert)
                    alert.addAction(title: "OK", style: .cancel, handler: nil)
                    present(alert, animated: true, completion: nil)
                }
            }
            serverShuffleLoader = nil
        }
        loader.startLoad()
        serverShuffleLoader = loader
    }
    
    @objc private func cancelLoad() {
        HUD.hide()
        quickAlbumsLoader?.cancelLoad()
        quickAlbumsLoader = nil
        serverShuffleLoader?.cancelLoad()
        serverShuffleLoader = nil
        searchLoader?.cancelLoad()
        searchLoader = nil
    }
    
    @objc private func jukeboxOff() {
        jukeboxButton.setIcon(image: UIImage(named: "home-jukebox-off"))
        jukeboxButton.setTitle(title: "Jukebox\nMode is OFF")
        initSongInfo()
    }
    
    @objc private func didEnterOnlineMode() {
        searchBar.enable()
        topRowStack.enable()
        songInfoButton.enable()
        nowPlayingButton.enable()
        chatButton.enable()
        songInfoButtonAlpha = 1
    }
    
    @objc private func didEnterOfflineMode() {
        searchBar.disable()
        topRowStack.disable()
        songInfoButton.disable()
        nowPlayingButton.disable()
        chatButton.disable()
        songInfoButtonAlpha = songInfoButton.alpha
    }
}

extension HomeViewController: UISearchBarDelegate {
    private var isTagSearchSupported: Bool { settings.currentServer?.isTagSearchSupported ?? false }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        if traitCollection.userInterfaceStyle == .dark {
            searchOverlay.effect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        } else {
            searchOverlay.effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        }
        
        view.addSubview(searchOverlay)
        if isTagSearchSupported {
            searchOverlay.snp.makeConstraints { make in
                make.top.equalTo(searchSegmentContainer.snp.bottom)
                make.leading.trailing.bottom.equalToSuperview()
            }
        } else {
            searchOverlay.snp.makeConstraints { make in
                make.top.equalTo(searchBarContainer.snp.bottom)
                make.leading.trailing.bottom.equalToSuperview()
            }
        }
        
        searchOverlay.alpha = 0
        searchOverlay.contentView.addSubview(dismissButton)
        dismissButton.snp.makeConstraints { make in
            make.leading.trailing.top.bottom.equalToSuperview()
        }
        
        UIView.animate(withDuration: 0.2) {
            if self.isTagSearchSupported {
                self.searchSegment.isEnabled = true
                self.searchSegment.alpha = 1
                self.searchSegmentContainer.alpha = 1
            }
            self.searchOverlay.alpha = 1
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        UIView.animate(withDuration: 0.2) {
            if self.isTagSearchSupported {
                self.searchSegment.isEnabled = false
                self.searchSegment.alpha = 0
                self.searchSegmentContainer.alpha = 0
            }
            self.searchOverlay.alpha = 0
        } completion: { _ in
            self.searchOverlay.removeFromSuperview()
            searchBar.resignFirstResponder()
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        
        guard let query = searchBar.text else { return }
        
        var searchType = SearchLoader.SearchType.old
        if isTagSearchSupported {
            searchType = searchSegment.selectedSegmentIndex == 0 ? .folder : .tag
        }
        HUD.show()
        searchLoader = SearchLoader(serverId: serverId, searchType: searchType, searchItemType: .all, query: query)
        searchLoader?.callback = { [weak self] _, success, error in
            HUD.hide()
            guard let self = self, let searchLoader = self.searchLoader else { return }
            
            if success {
                if searchLoader.searchType == .old {
                    let controller = SearchSongsViewController(serverId: self.serverId, query: query, searchType: searchType, searchItemType: .songs, songs: searchLoader.songs)
                    self.pushViewControllerCustom(controller)
                } else {
                    let controller = SearchAllViewController(serverId: self.serverId, query: query, searchType: searchType, folderArtists: searchLoader.folderArtists, folderAlbums: searchLoader.folderAlbums, tagArtists: searchLoader.tagArtists, tagAlbums: searchLoader.tagAlbums, songs: searchLoader.songs)
                    self.pushViewControllerCustom(controller)
                }
            } else if let error = error {
                if self.settings.isPopupsEnabled {
                    let alert = UIAlertController(title: "Error", message: "There was an error completing the search.\n\nError: \(error.localizedDescription)", preferredStyle: .alert)
                    alert.addAction(title: "OK", style: .cancel, handler: nil)
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
        searchLoader?.startLoad()
    }
}
