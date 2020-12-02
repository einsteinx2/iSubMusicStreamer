//
//  HomeViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 11/14/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

@objc class HomeViewController: UIViewController {
    private var quickAlbumsLoader: SUSQuickAlbumsLoader?
    private var serverShuffleLoader: SUSServerShuffleLoader?
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

    private let quickAlbumsButton = HomeViewButton(icon: UIImage(named: "home-quick-ipad"), title: "Quick\nAlbums")
    private let serverShuffleButton = HomeViewButton(icon: UIImage(named: "home-shuffle-ipad"), title: "Server\nShuffle")
    private let jukeboxButton = HomeViewButton(icon: UIImage(named: "home-jukebox-off-ipad"), title: "Jukebox\nMode OFF")
    private let settingsButton = HomeViewButton(icon: UIImage(named: "home-settings-ipad"), title: "App\nSettings")
    private let spacerButton = HomeViewButton(icon: nil, title: "")
    private let chatButton = HomeViewButton(icon: UIImage(named: "home-chat-ipad"), title: "Server\nChat")
    private var buttons: [HomeViewButton] {
        return [quickAlbumsButton, serverShuffleButton, jukeboxButton, settingsButton, spacerButton, chatButton]
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard verticalStack.superview != nil else { return }
        view.setNeedsUpdateConstraints()
    }
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        if UIApplication.orientation().isPortrait || UIDevice.isIPad() {
            for button in buttons {
                button.showLabel()
            }
            searchSegment.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(13)
                make.trailing.equalToSuperview().offset(-13)
                make.top.equalToSuperview().offset(5)
                make.bottom.equalToSuperview().offset(-10)
            }
            verticalStack.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(20)
                make.trailing.equalToSuperview().offset(-20)
                make.centerY.equalToSuperview().offset(15)
                make.height.equalToSuperview().multipliedBy(0.75)
            }
            songInfoButton.snp.remakeConstraints { make in
                make.height.equalTo(80)
                make.leading.equalToSuperview().offset(35)
                make.trailing.equalToSuperview().offset(-30)
                make.centerY.equalTo(verticalStack)
            }
        } else {
            for button in buttons {
                button.hideLabel()
            }
            searchSegment.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(52)
                make.trailing.equalToSuperview().offset(-52)
                make.top.equalToSuperview().offset(5)
                make.bottom.equalToSuperview().offset(-10)
            }
            verticalStack.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(20)
                make.trailing.equalToSuperview().offset(-20)
                make.centerY.equalToSuperview().offset(15)
                make.height.equalToSuperview().multipliedBy(0.60)
            }
            songInfoButton.snp.remakeConstraints { make in
                make.height.equalTo(80)
                make.width.equalToSuperview().dividedBy(2)
                make.centerX.equalToSuperview()
                make.centerY.equalTo(bottomRowStack)
            }
        }
    }
    
    private func registerNotifications() {
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(jukeboxOff), name: ISMSNotification_JukeboxDisabled)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(initSongInfo), name: ISMSNotification_SongPlaybackStarted)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(initSongInfo), name: ISMSNotification_ServerSwitched)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(performServerShuffle(notification:)), name: "performServerShuffle")
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(addURLRefBackButton), name: UIApplication.didBecomeActiveNotification.rawValue)
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Home"
        // Not sure why, but it's necessary to set this on the navigation item only in this controller
        navigationItem.title = "Home"
        
        registerNotifications()
        
        quickAlbumsButton.setAction { [unowned self] in
            let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: "Recently Played", style: .default) { action in
                self.loadQuickAlbums(modifier: "recent", title: action.title ?? "")
            })
            sheet.addAction(UIAlertAction(title: "Frequently Played", style: .default) { action in
                self.loadQuickAlbums(modifier: "frequent", title: action.title ?? "")
            })
            sheet.addAction(UIAlertAction(title: "Recently Added", style: .default) { action in
                self.loadQuickAlbums(modifier: "newest", title: action.title ?? "")
            })
            sheet.addAction(UIAlertAction(title: "Random Albums", style: .default) { action in
                self.loadQuickAlbums(modifier: "random", title: action.title ?? "")
            })
            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            if let popoverPresentationController = sheet.popoverPresentationController {
                // Fix exception on iPad
                popoverPresentationController.sourceView = self.quickAlbumsButton
                popoverPresentationController.sourceRect = self.quickAlbumsButton.bounds
            }
            present(sheet, animated: true, completion: nil)
        }
        
        serverShuffleButton.setAction { [unowned self] in
            let folders = SUSRootFoldersDAO.folderDropdownFolders()
            if let folders = folders {
                if folders.count == 2 {
                    self.performServerShuffle(notification: nil)
                } else {
                    let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                    sheet.addAction(UIAlertAction(title: "All Folders", style: .default) { action in
                        let userInfo = ["folderId": -1]
                        NotificationCenter.postNotificationToMainThread(name: "performServerShuffle", userInfo: userInfo)
                    })
                    for (folderId, name) in folders {
                        if let folderId = folderId as? NSNumber, let name = name as? String, folderId != -1 {
                            sheet.addAction(UIAlertAction(title: name, style: .default) { action in
                                let userInfo = ["folderId": folderId]
                                NotificationCenter.postNotificationToMainThread(name: "performServerShuffle", userInfo: userInfo)
                            })
                        }
                    }
                    sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
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
            if Settings.shared().isJukeboxEnabled {
                self.jukeboxButton.setIcon(image: UIImage(named: "home-jukebox-off-ipad"))
                Settings.shared().isJukeboxEnabled = false
                AppDelegate.shared().window.backgroundColor = ViewObjects.shared().windowColor
                NotificationCenter.postNotificationToMainThread(name: ISMSNotification_JukeboxDisabled)
                Flurry.logEvent("JukeboxDisabled")
            } else {
                AudioEngine.shared().player?.stop()
                self.jukeboxButton.setIcon(image: UIImage(named: "home-jukebox-on-ipad"))
                Settings.shared().isJukeboxEnabled = true
                Jukebox.shared().getInfo()
                AppDelegate.shared().window.backgroundColor = ViewObjects.shared().jukeboxColor
                NotificationCenter.postNotificationToMainThread(name: ISMSNotification_JukeboxEnabled)
                Flurry.logEvent("JukeboxEnabled")
            }
            self.initSongInfo()
        }
        
        topRowStack.translatesAutoresizingMaskIntoConstraints = false
        topRowStack.addArrangedSubviews([quickAlbumsButton, serverShuffleButton, jukeboxButton])
        topRowStack.axis = .horizontal
        topRowStack.distribution = .equalCentering
        
        settingsButton.setAction {
            AppDelegate.shared().showSettings()
        }
        
        spacerButton.isUserInteractionEnabled = false
        
        chatButton.setAction { [unowned self] in
            let controller = ChatViewController(nibName: "ChatViewController", bundle: nil)
            navigationController?.pushViewController(controller, animated: true)
        }
        
        bottomRowStack.translatesAutoresizingMaskIntoConstraints = false
        bottomRowStack.addArrangedSubviews([settingsButton, spacerButton, chatButton])
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
        
        searchSegmentContainer.backgroundColor = UIColor(named: "isubBackgroundColor")
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
        
        songInfoButton.translatesAutoresizingMaskIntoConstraints = false
        songInfoButton.setAction { [unowned self] in
            self.nowPlayingAction(sender: nil)
        }
        view.addSubview(songInfoButton)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addURLRefBackButton()
        navigationItem.rightBarButtonItem = Music.shared().showPlayerIcon ? UIBarButtonItem(image: UIImage(named: "now-playing"), style: .plain, target: self, action: #selector(nowPlayingAction(sender:))) : nil
        
        let jukeboxImageName = Settings.shared().isJukeboxEnabled ? "home-jukebox-on-ipad" : "home-jukebox-off-ipad"
        jukeboxButton.setIcon(image: UIImage(named: jukeboxImageName))
        
        searchSegment.alpha = 0.0
        searchSegment.isEnabled = false
        searchSegmentContainer.alpha = 0.0
        
        initSongInfo()
        
        Flurry.logEvent("HomeTab")
    }
    
    @objc private func initSongInfo() {
        songInfoButton.update(song: PlayQueue.shared().currentSong() ?? PlayQueue.shared().prevSong())
    }
    
    private func loadQuickAlbums(modifier: String, title: String) {
        ViewObjects.shared().showAlbumLoadingScreen(AppDelegate.shared().window, sender: self)
        let loader = SUSQuickAlbumsLoader { _, error, loader in
            ViewObjects.shared().hideLoadingScreen()
            if let error = error {
                if Settings.shared().isPopupsEnabled && (error as NSError).code != NSURLErrorCancelled {
                    let alert = UIAlertController(title: "Error", message: "There was an error grabbing the album list.\n\nError: \(error.localizedDescription)", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            } else if let loader = loader as? SUSQuickAlbumsLoader {
                let controller = HomeAlbumViewController(nibName: "HomeAlbumViewController", bundle: nil)
                controller.modifier = modifier
                controller.title = title
                controller.listOfAlbums = loader.listOfAlbums
                self.pushCustom(controller)
            }
            self.quickAlbumsLoader = nil
        }
        loader.modifier = modifier
        quickAlbumsLoader = loader
        loader.startLoad()
    }
    
    @objc private func performServerShuffle(notification: Notification?) {
        ViewObjects.shared().showAlbumLoadingScreen(AppDelegate.shared().window, sender: self)
        let loader = SUSServerShuffleLoader { success, _, loader in
            ViewObjects.shared().hideLoadingScreen()
            if success {
                Music.shared().playSong(atPosition: 0)
                self.showPlayer()
            } else {
                if Settings.shared().isPopupsEnabled {
                    let alert = UIAlertController(title: "Error", message: "There was an error creating the server shuffle list.\n\nThe connection could not be created", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
            self.serverShuffleLoader = nil
        }
        loader.folderId = notification?.userInfo?["folderId"] as? NSNumber
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
        ViewObjects.shared().hideLoadingScreen()
    }
    
    @objc private func jukeboxOff() {
        jukeboxButton.setIcon(image: UIImage(named: "home-jukebox-off-ipad"))
        initSongInfo()
    }
    
    @objc private func addURLRefBackButton() {
        if AppDelegate.shared().referringAppUrl != nil && AppDelegate.shared().mainTabBarController.selectedIndex != 4 {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: AppDelegate.shared(), action: #selector(AppDelegate.backToReferringApp))
        }
    }
    
    @objc private func nowPlayingAction(sender: Any?) {
        let controller = PlayerViewController()
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: true)
    }
}

extension HomeViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        if traitCollection.userInterfaceStyle == .dark {
            searchOverlay.effect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        } else {
            searchOverlay.effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        }
        
        view.addSubview(searchOverlay)
        if Settings.shared().isNewSearchAPI {
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
            if Settings.shared().isNewSearchAPI {
                self.searchSegment.isEnabled = true
                self.searchSegment.alpha = 1
                self.searchSegmentContainer.alpha = 1
            }
            self.searchOverlay.alpha = 1
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        UIView.animate(withDuration: 0.2) {
            if Settings.shared().isNewSearchAPI {
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
        
        var query = searchBar.text?.trimmingLeadingAndTrailingWhitespace() ?? ""
        var parameters = [String: String]()
        var action = ""
        if Settings.shared().isNewSearchAPI {
            // Due to a Subsonic bug, to get good search results, we need to add a * to the end of
            // Latin based languages, but not to unicode languages like Japanese.
            if query.canBeConverted(to: .isoLatin1) {
                query += "*"
            }
            
            action = "search2"
            parameters = ["query": query, "artistCount": "0", "albumCount": "0", "songCount": "0"]
            switch searchSegment.selectedSegmentIndex {
            case 0: parameters["artistCount"] = "20"
            case 1: parameters["albumCount"] = "20"
            case 2: parameters["songCount"] = "20"
            default:
                parameters["artistCount"] = "20"
                parameters["albumCount"] = "20"
                parameters["songCount"] = "20"
            }
        } else {
            action = "search"
            parameters = ["count": "20", "any": query]
        }
        
        let request = NSMutableURLRequest(susAction: action, parameters: parameters)
        if let request = request as URLRequest? {
            dataTask = SUSLoader.sharedSession().dataTask(with: request) { data, _, error in
                EX2Dispatch.runInMainThreadAsync {
                    if let error = error {
                        if Settings.shared().isPopupsEnabled {
                            let alert = UIAlertController(title: "Error", message: "There was an error completing the search.\n\nError: \(error.localizedDescription)", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        }
                    } else if let data = data {
                        let xmlParser = XMLParser(data: data)
                        let parser = SearchXMLParser()
                        xmlParser.delegate = parser
                        xmlParser.parse()
                        
                        if Settings.shared().isNewSearchAPI && self.searchSegment.selectedSegmentIndex == 3 {
                            let controller = SearchAllViewController(nibName: "SearchAllViewController", bundle: nil)
                            controller.listOfArtists = parser.listOfArtists
                            controller.listOfAlbums = parser.listOfAlbums
                            controller.listOfSongs = parser.listOfSongs
                            controller.query = query
                            self.pushCustom(controller)
                        } else {
                            let controller = SearchSongsViewController(nibName: "SearchSongsViewController", bundle: nil)
                            controller.title = "Search"
                            if Settings.shared().isNewSearchAPI {
                                if self.searchSegment.selectedSegmentIndex == 0 {
                                    controller.listOfArtists = NSMutableArray(array: parser.listOfArtists)
                                } else if self.searchSegment.selectedSegmentIndex == 1 {
                                    controller.listOfAlbums = NSMutableArray(array: parser.listOfAlbums)
                                } else if self.searchSegment.selectedSegmentIndex == 2 {
                                    controller.listOfSongs = NSMutableArray(array: parser.listOfSongs)
                                }
                                controller.searchType = ISMSSearchSongsSearchType(rawValue: ISMSSearchSongsSearchType.RawValue(self.searchSegment.selectedSegmentIndex))
                                controller.query = query
                            } else {
                                controller.listOfSongs = NSMutableArray(array: parser.listOfSongs)
                                controller.searchType = ISMSSearchSongsSearchType_Songs
                                controller.query = query
                            }
                            self.pushCustom(controller)
                        }
                    }
                    ViewObjects.shared().hideLoadingScreen()
                }
            }
            dataTask?.resume()
            ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: "")
        }
    }
}

private class HomeViewButton: UIView {
    private let button = UIButton(type: .custom)
    private let label = UILabel()
    
    init(icon: UIImage?, title: String, actionHandler: (() -> ())? = nil) {
        super.init(frame: CGRect.zero)
                
        button.setImage(icon, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.setImage(icon, for: .normal)
        if let actionHandler = actionHandler {
            button.addClosure(for: .touchUpInside, closure: actionHandler)
        }
        addSubview(button)
        button.snp.makeConstraints { make in
            make.width.height.equalTo(70)
            make.top.centerX.equalToSuperview()
        }
        
        label.font = .boldSystemFont(ofSize: 20)
        label.numberOfLines = 2
        label.text = title;
        label.textAlignment = .center
        label.textColor = .label
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    func setIcon(image: UIImage?) {
        button.setImage(image, for: .normal)
    }
    
    func setTitle(title: String) {
        button.setTitle(title, for: .normal)
    }
    
    func setAction(handler: @escaping () -> ()) {
        button.addClosure(for: .touchUpInside, closure: handler)
    }
    
    func hideLabel() {
        label.removeFromSuperview()
        invalidateIntrinsicContentSize()
    }
    
    func showLabel() {
        addSubview(label)
        label.snp.remakeConstraints { make in
            make.top.equalTo(button.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        invalidateIntrinsicContentSize()
    }
    
    override var intrinsicContentSize: CGSize {
        if label.superview != nil {
            return CGSize(width: 120, height: 120)
        } else {
            return CGSize(width: 120, height: 70)
        }
    }
}

private class HomeSongInfoButton: UIView {
    private let coverArt = AsynchronousImageView()
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
            coverArt.coverArtId = song.coverArtId
            songLabel.text = song.title
            artistLabel.text = song.artist
        } else {
            coverArt.image = UIImage(named: "default-album-art-small")
            songLabel.text = nil
            artistLabel.text = nil
        }
    }
}
