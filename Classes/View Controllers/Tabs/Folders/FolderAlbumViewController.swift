//
//  FolderAlbumViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import Resolver

@objc final class FolderAlbumViewController: UIViewController {
    @Injected private var store: Store
    @Injected private var settings: Settings
    @Injected private var viewObjects: ViewObjects
    
    var serverId = Settings.shared().currentServerId
    
    private let folderArtist: FolderArtist?
    private let folderAlbum: FolderAlbum?
    private let parentFolderId: Int
    private var loader: SubfolderLoader?
    
    private var metadata: FolderMetadata?
    private var folderAlbumIds = [Int]()
    private var songIds = [Int]()
    
    private let tableView = UITableView()
    
    @objc var hasLoaded: Bool { metadata != nil }
    @objc var folderCount: Int { metadata?.folderCount ?? 0 }
    @objc var songCount: Int { metadata?.songCount ?? 0 }
    @objc var duration: Int { metadata?.duration ?? 0 }
    
    @objc init(folderArtist: FolderArtist) {
        self.folderArtist = folderArtist
        self.folderAlbum = nil
        self.parentFolderId = folderArtist.id
        super.init(nibName: nil, bundle: nil)
    }
    
    @objc init(folderAlbum: FolderAlbum) {
        self.folderArtist = nil
        self.folderAlbum = folderAlbum
        self.parentFolderId = folderAlbum.id
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    deinit {
        cancelLoad()
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Colors.background
        title = folderArtist?.name ?? folderAlbum?.name
        
        setupDefaultTableView(tableView)
        tableView.refreshControl = RefreshControl { [unowned self] in
            startLoad()
        }
        
        if hasLoaded {
            addHeader()
            addSectionIndex()
        } else {
            startLoad()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        addShowPlayerButton()
        tableView.reloadData()
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadData), name: ISMSNotification_CurrentPlaylistIndexChanged)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadData), name: ISMSNotification_SongPlaybackStarted)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        cancelLoad()
        
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_CurrentPlaylistIndexChanged)
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_SongPlaybackStarted)
    }
    
    // Autolayout solution described here: https://medium.com/@aunnnn/table-header-view-with-autolayout-13de4cfc4343
    private func addHeader() {
        guard folderAlbumIds.count > 0 || songIds.count > 0 else {
            tableView.tableHeaderView = nil
            return
        }
        
        // Create the container view and constrain it to the table
        let headerView = UIView()
        tableView.tableHeaderView = headerView
        headerView.snp.makeConstraints { make in
            make.centerX.width.top.equalToSuperview()
        }
        
        // Create the album header view and constrain to the container view
        let albumHeader: AlbumTableViewHeader?
        if let folderAlbum = folderAlbum {
            albumHeader = AlbumTableViewHeader(folderAlbum: folderAlbum, tracks: songCount, duration: Double(duration))
            headerView.addSubview(albumHeader!)
            albumHeader!.snp.makeConstraints { make in
                make.leading.trailing.top.equalToSuperview()
            }
        } else {
            albumHeader = nil
        }
        
        // Create the play all and shuffle buttons and constrain to the container view
        let playAllAndShuffleHeader = PlayAllAndShuffleHeader(playAllHandler: { [unowned self] in
            SongLoader.playAll(folderId: parentFolderId)
        }, shuffleHandler: { [unowned self] in
            SongLoader.shuffleAll(folderId: parentFolderId)
        })
        headerView.addSubview(playAllAndShuffleHeader)
        playAllAndShuffleHeader.snp.makeConstraints { make in
            if let albumHeader = albumHeader {
                make.top.equalTo(albumHeader.snp.bottom)
            } else {
                make.top.equalToSuperview()
            }
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        // Force re-layout using the constraints
        tableView.tableHeaderView?.layoutIfNeeded()
        tableView.tableHeaderView = tableView.tableHeaderView
    }
    
    private func addSectionIndex() {
        
    }
    
    @objc private func reloadData() {
        tableView.reloadData()
    }
    
    private func loadFromCache() {
        metadata = store.folderMetadata(serverId: serverId, parentFolderId: parentFolderId)
        if metadata != nil {
            folderAlbumIds = store.folderAlbumIds(serverId: serverId, parentFolderId: parentFolderId)
            songIds = store.songIds(serverId: serverId, parentFolderId: parentFolderId)
        } else {
            folderAlbumIds.removeAll()
            songIds.removeAll()
        }
    }
    
    func startLoad() {
        viewObjects.showAlbumLoadingScreen(view, sender: self)
        loader = SubfolderLoader(parentFolderId: parentFolderId) { [weak self] success, error in
            guard let self = self else { return }
            
            if let loader = self.loader {
                self.metadata = loader.folderMetadata
                self.folderAlbumIds = loader.folderAlbumIds
                self.songIds = loader.songIds
            }
            self.loader = nil
            
            if success {
                self.tableView.reloadData()
                self.addHeader()
                self.addSectionIndex()
            } else if let error = error as NSError? {
                if self.settings.isPopupsEnabled {
                    let message = "There was an error loading the album.\n\nError \(error.code): \(error.localizedDescription)"
                    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                    alert.addCancelAction(title: "OK")
                    self.present(alert, animated: true, completion: nil)
                }
            }
            self.viewObjects.hideLoadingScreen()
            self.tableView.refreshControl?.endRefreshing()
        }
        loader?.startLoad()
    }
    
    func cancelLoad() {
        loader?.cancelLoad()
        loader?.callback = nil
        loader = nil
        
        tableView.refreshControl?.endRefreshing()
        viewObjects.hideLoadingScreen()
    }
}

extension FolderAlbumViewController: UITableViewConfiguration {
    private func folderAlbum(indexPath: IndexPath) -> FolderAlbum? {
        guard indexPath.row < folderAlbumIds.count else { return nil }
        return store.folderAlbum(serverId: serverId, id: folderAlbumIds[indexPath.row])
    }
    
    private func song(indexPath: IndexPath) -> Song? {
        guard indexPath.row < songIds.count else { return nil }
        return store.song(serverId: serverId, id: songIds[indexPath.row])
    }
    
    private func playSong(indexPath: IndexPath) -> Song? {
        guard indexPath.section == 1, indexPath.row < songIds.count else { return nil }
        return store.playSong(position: indexPath.row, songIds: songIds, serverId: serverId)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? folderAlbumIds.count : songIds.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        if indexPath.section == 0 {
            cell.show(cached: false, number: false, art: true, secondary: false, duration: false)
            cell.update(model: folderAlbum(indexPath: indexPath))
        } else {
            if let song = song(indexPath: indexPath) {
                var showNumber = false
                if song.track > 0 {
                    showNumber = true
                    cell.number = song.track
                }
                cell.show(cached: true, number: showNumber, art: false, secondary: true, duration: true)
                cell.update(model: song)
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            if let folderAlbum = folderAlbum(indexPath: indexPath) {
                let controller = FolderAlbumViewController(folderAlbum: folderAlbum)
                pushViewControllerCustom(controller)
            }
        } else {
            if let song = playSong(indexPath: indexPath), !song.isVideo {
                showPlayer()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if indexPath.section == 0 {
            return SwipeAction.downloadAndQueueConfig(model: folderAlbum(indexPath: indexPath))
        } else {
            if let song = song(indexPath: indexPath), !song.isVideo {
                return SwipeAction.downloadAndQueueConfig(model: song)
            }
        }
        return nil
    }
}
