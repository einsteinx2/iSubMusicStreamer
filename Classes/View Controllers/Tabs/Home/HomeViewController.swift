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
    
    var serverId: Int { Settings.shared().currentServerId }
    
    private var quickAlbumsLoader: QuickAlbumsLoader?
    private var serverShuffleLoader: ServerShuffleLoader?
    private var dataTask: URLSessionDataTask?
    
    private let searchBarContainer = UIView()
    private let searchBar = UISearchBar()
    private let searchSegmentContainer = UIView()
    private let searchSegment = UISegmentedControl()
    private let searchOverlay = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let dismissButton = UIButton(type: .custom)
    
    private let songInfoButton = HomeSongInfoButton()
    
    private let topRowStack = UIStackView()
    private let bottomRowStack = UIStackView()
    private let verticalStack = UIStackView()
    
    private let quickAlbumsButton = HomeViewButton(icon: UIImage(named: "home-quick"), title: "Quick\nAlbums")
    private let serverShuffleButton = HomeViewButton(icon: UIImage(named: "home-shuffle"), title: "Server\nShuffle")
    private let jukeboxButton = HomeViewButton(icon: UIImage(named: "home-jukebox-off"), title: "Jukebox\nMode OFF")
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
        let iphoneOffset = UIDevice.isSmall ? 0 : 20
        if UIApplication.orientation.isPortrait || UIDevice.isPad {
            for button in buttons {
                button.showLabel()
            }
            songInfoButton.alpha = 1
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
                        performServerShuffle(mediaFolderId: MediaFolder.allFoldersId)
                    }
                    for mediaFolder in mediaFolders {
                        if mediaFolder.id != MediaFolder.allFoldersId {
                            sheet.addAction(title: mediaFolder.name, style: .default) { action in
                                performServerShuffle(mediaFolderId: mediaFolder.id)
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
                settings.isJukeboxEnabled = false
                NotificationCenter.postOnMainThread(name: Notifications.jukeboxDisabled)
                Flurry.logEvent("JukeboxDisabled")
            } else {
                player.stop()
                self.jukeboxButton.setIcon(image: UIImage(named: "home-jukebox-on"))
                settings.isJukeboxEnabled = true
                self.jukebox.getInfo()
                NotificationCenter.postOnMainThread(name: Notifications.jukeboxEnabled)
                Flurry.logEvent("JukeboxEnabled")
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
        
        searchSegment.insertSegment(withTitle: "Artists", at: 0, animated: false)
        searchSegment.insertSegment(withTitle: "Albums", at: 1, animated: false)
        searchSegment.insertSegment(withTitle: "Songs", at: 2, animated: false)
        searchSegment.insertSegment(withTitle: "All", at: 3, animated: false)
        searchSegment.selectedSegmentIndex = 3
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
            make.leading.equalToSuperview().offset(UIDevice.isSmall ? 15 : 35)
            make.trailing.equalToSuperview().offset(UIDevice.isSmall ? -15 : -30)
            make.centerY.equalTo(verticalStack)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addURLRefBackButton()
        
        let jukeboxImageName = settings.isJukeboxEnabled ? "home-jukebox-on" : "home-jukebox-off"
        jukeboxButton.setIcon(image: UIImage(named: jukeboxImageName))
        
        searchSegment.alpha = 0.0
        searchSegment.isEnabled = false
        searchSegmentContainer.alpha = 0.0
        
        initSongInfo()
        
        Flurry.logEvent("HomeTab")
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
        quickAlbumsLoader?.cancelLoad()
        quickAlbumsLoader = nil
        serverShuffleLoader?.cancelLoad()
        serverShuffleLoader = nil
        dataTask?.cancel()
        dataTask = nil
        HUD.hide()
    }
    
    @objc private func jukeboxOff() {
        jukeboxButton.setIcon(image: UIImage(named: "home-jukebox-off"))
        initSongInfo()
    }
}

extension HomeViewController: UISearchBarDelegate {
    private var isNewSearchSupported: Bool { settings.currentServer?.isNewSearchSupported ?? false }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        if traitCollection.userInterfaceStyle == .dark {
            searchOverlay.effect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        } else {
            searchOverlay.effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        }
        
        view.addSubview(searchOverlay)
        if settings.currentServer?.isNewSearchSupported == true {
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
            if self.isNewSearchSupported {
                self.searchSegment.isEnabled = true
                self.searchSegment.alpha = 1
                self.searchSegmentContainer.alpha = 1
            }
            self.searchOverlay.alpha = 1
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        UIView.animate(withDuration: 0.2) {
            if self.isNewSearchSupported {
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
        
        var query = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var parameters = [String: Any]()
        var action = ""
        if isNewSearchSupported {
            // Due to a Subsonic bug, to get good search results, we need to add a * to the end of
            // Latin based languages, but not to unicode languages like Japanese.
            if query.canBeConverted(to: .isoLatin1) {
                query += "*"
            }

            action = "search2"
            parameters = ["query": query, "artistCount": 0, "albumCount": 0, "songCount": 0]
            switch searchSegment.selectedSegmentIndex {
            case 0: parameters["artistCount"] = 20
            case 1: parameters["albumCount"] = 20
            case 2: parameters["songCount"] = 20
            default:
                parameters["artistCount"] = 20
                parameters["albumCount"] = 20
                parameters["songCount"] = 20
            }
        } else {
            action = "search"
            parameters = ["count": 20, "any": query]
        }
        
        // TODO: implement this
        // TODO: Don't hard code server id
        guard let request = URLRequest(serverId: serverId, subsonicAction: action, parameters: parameters) else {
            DDLogError("[HomeViewController] failed to create URLRequest to search with action \(action) and parameters \(parameters)")
            return
        }
        
        dataTask = APILoader.sharedSession.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    if self.settings.isPopupsEnabled {
                        let alert = UIAlertController(title: "Error", message: "There was an error completing the search.\n\nError: \(error.localizedDescription)", preferredStyle: .alert)
                        alert.addAction(title: "OK", style: .cancel, handler: nil)
                        self.present(alert, animated: true, completion: nil)
                    }
                } else if let data = data {
                    DDLogVerbose("search results: \(String(data: data, encoding: .utf8)!)")
                    let parser = SearchXMLParser(serverId: self.serverId, data: data)
                    
                    if self.isNewSearchSupported && self.searchSegment.selectedSegmentIndex == 3 {
                        let controller = SearchAllViewController()
                        controller.folderArtists = parser.folderArtists
                        controller.folderAlbums = parser.folderAlbums
                        controller.songs = parser.songs
                        controller.query = query
                        self.pushViewControllerCustom(controller)
                    } else {
                        let controller = SearchSongsViewController()
                        controller.title = "Search"
                        if self.isNewSearchSupported {
                            if self.searchSegment.selectedSegmentIndex == 0 {
                                controller.folderArtists = parser.folderArtists
                                controller.searchType = .artists
                            } else if self.searchSegment.selectedSegmentIndex == 1 {
                                controller.folderAlbums = parser.folderAlbums
                                controller.searchType = .albums
                            } else if self.searchSegment.selectedSegmentIndex == 2 {
                                controller.songs = parser.songs
                                controller.searchType = .songs
                            }
                            controller.query = query
                        } else {
                            controller.songs = parser.songs
                            controller.searchType = .songs
                            controller.query = query
                        }
                        self.pushViewControllerCustom(controller)
                    }
                }
                HUD.hide()
            }
        }
        dataTask?.resume()
        HUD.show()
    }
}
