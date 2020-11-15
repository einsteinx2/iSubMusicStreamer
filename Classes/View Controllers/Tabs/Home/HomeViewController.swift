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

    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard verticalStack.superview != nil else { return }
        self.view.setNeedsUpdateConstraints()
        coordinator.animate(alongsideTransition: { _ in
            self.songInfoButton.alpha = UIApplication.orientation().isPortrait ? 1 : 0;
        }, completion: nil)
    }
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        self.remakeConstraints()
    }
    
    private func registerNotifications() {
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(jukeboxOff), name: ISMSNotification_JukeboxDisabled, object: nil)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(initSongInfo), name: ISMSNotification_SongPlaybackStarted, object: nil)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(initSongInfo), name: ISMSNotification_ServerSwitched, object: nil)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(performServerShuffle(notification:)), name: "performServerShuffle", object: nil)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(addURLRefBackButton), name: UIApplication.didBecomeActiveNotification.rawValue, object: nil)
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Home"
        
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
            present(sheet, animated: true, completion: nil)
        }
        
        serverShuffleButton.setAction { [unowned self] in
            let folders = SUSRootFoldersDAO.folderDropdownFolders()
            if let folders = folders {
                if folders.count == 2 {
                    self.performServerShuffle(notification: nil)
                } else {
                    var height = 65.0 + Double(folders.count * 44)
                    if height > 300.0 {
                        height = 300.0
                    }
                    
                    let folderPicker = FolderPickerDialog(frame: CGRect(x: 0, y: 0, width: 300, height: height))
                    folderPicker.titleLabel.text = "Folder to Shuffle"
                    folderPicker.show()
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
                Jukebox.shared().jukeboxGetInfo()
                AppDelegate.shared().window.backgroundColor = ViewObjects.shared().jukeboxColor
                NotificationCenter.postNotificationToMainThread(name: ISMSNotification_JukeboxEnabled)
                Flurry.logEvent("JukeboxEnabled")
            }
            self.initSongInfo()
        }
        
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
        
        bottomRowStack.addArrangedSubviews([settingsButton, spacerButton, chatButton])
        bottomRowStack.axis = .horizontal
        bottomRowStack.distribution = .equalCentering

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
        searchBarContainer.addSubview(searchBar)
        searchBar.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(5)
            make.trailing.bottom.equalToSuperview().offset(-5)
        }
        
        searchSegmentContainer.backgroundColor = .systemBackground
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
        
        songInfoButton.setAction { [unowned self] in
            self.nowPlayingAction(sender: nil)
        }
        songInfoButton.alpha = UIApplication.orientation().isPortrait ? 1 : 0;
        view.addSubview(songInfoButton)
        songInfoButton.snp.makeConstraints { make in
            make.height.equalTo(80)
            make.leading.equalToSuperview().offset(35)
            make.trailing.equalToSuperview().offset(-30)
            make.centerY.equalToSuperview()
        }
        
        remakeConstraints()
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
        
        Flurry.logEvent("HomeTab")
    }
    
    private func remakeConstraints() {
        if UIApplication.orientation().isPortrait {
            for button in buttons {
                button.showLabel()
            }
            verticalStack.snp.remakeConstraints { make in
                make.top.equalTo(searchBarContainer.snp.bottom).offset(100)
                make.leading.equalToSuperview().offset(20)
                make.trailing.equalToSuperview().offset(-20)
                make.bottom.equalToSuperview().offset(-100)
            }
            searchSegment.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(13)
                make.trailing.equalToSuperview().offset(-13)
                make.top.equalToSuperview().offset(5)
                make.bottom.equalToSuperview().offset(-10)
            }
        } else {
            for button in buttons {
                button.hideLabel()
            }
            verticalStack.snp.remakeConstraints { make in
                make.top.equalTo(searchBarContainer.snp.bottom).offset(30)
                make.leading.equalToSuperview().offset(100)
                make.trailing.equalToSuperview().offset(-100)
                make.bottom.equalToSuperview().offset(-30)
            }
            searchSegment.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(52)
                make.trailing.equalToSuperview().offset(-52)
                make.top.equalToSuperview().offset(5)
                make.bottom.equalToSuperview().offset(-10)
            }
        }
    }
    
    @objc private func initSongInfo() {
        songInfoButton.update(song: PlayQueue.shared().currentSong() ?? PlayQueue.shared().prevSong())
    }
    
    private func loadQuickAlbums(modifier: String, title: String) {
        ViewObjects.shared().showAlbumLoadingScreen(AppDelegate.shared().window, sender: self)
        let loader = SUSQuickAlbumsLoader { _, error, loader in
            ViewObjects.shared().hideLoadingScreen()
            if let error = error {
                let alert = CustomUIAlertView(title: "Error", message: "There was an error grabbing the album list.\n\nError: \(error.localizedDescription)", delegate: nil, cancelButtonTitle: "OK")
                alert.show()
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
    }
    
    @objc private func performServerShuffle(notification: Notification?) {
        ViewObjects.shared().showAlbumLoadingScreen(AppDelegate.shared().window, sender: self)
        let loader = SUSServerShuffleLoader { success, _, loader in
            ViewObjects.shared().hideLoadingScreen()
            if success {
                Music.shared().playSong(atPosition: 0)
                self.showPlayer()
            } else {
                let alert = CustomUIAlertView(title: "Error", message: "There was an error creating the server shuffle list.\n\nThe connection could not be created", delegate: nil, cancelButtonTitle: "OK")
                alert.show()
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
        let controller = iPhoneStreamingPlayerViewController(nibName: "iPhoneStreamingPlayerViewController", bundle: nil)
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: true)
    }
}

extension HomeViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
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
        
        UIView.animate(withDuration: 0.3) {
            if Settings.shared().isNewSearchAPI {
                self.searchSegment.isEnabled = true
                self.searchSegment.alpha = 1
                self.searchSegmentContainer.alpha = 1
            }
            self.searchOverlay.alpha = 1
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        UIView.animate(withDuration: 0.3) {
            if Settings.shared().isNewSearchAPI {
                self.searchSegment.isEnabled = false
                self.searchSegment.alpha = 0
                self.searchSegmentContainer.alpha = 0
            }
            self.searchOverlay.alpha = 0
        } completion: { _ in
            self.searchOverlay.removeFromSuperview()
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
                        let message = "There was an error completing the search.\n\nError: \(error.localizedDescription)"
                        let alert = CustomUIAlertView(title: "Error", message: message, delegate: nil, cancelButtonTitle: "OK")
                        alert.show()
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
        layer.borderColor = UIColor.systemGray5.cgColor
        
        addSubview(coverArt)
        coverArt.snp.makeConstraints { make in
            make.width.equalTo(coverArt.snp.height)
            make.leading.top.bottom.equalToSuperview()
        }
        
        songLabel.font = .boldSystemFont(ofSize: 20)
        songLabel.textColor = .label
        addSubview(songLabel)
        songLabel.snp.makeConstraints { make in
            make.height.equalToSuperview().dividedBy(2)
            make.leading.equalTo(coverArt.snp.trailing).offset(5)
            make.trailing.equalToSuperview().offset(-5)
            make.top.equalToSuperview().offset(5)
        }
        
        artistLabel.font = .systemFont(ofSize: 18)
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
            coverArt.image = UIImage(named: "default-album-art")
            songLabel.text = nil
            artistLabel.text = nil
        }
    }
}
