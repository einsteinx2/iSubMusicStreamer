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

final class FolderAlbumViewController: CustomUITableViewController {
    private enum SectionType: Int, CaseIterable {
        case albums = 0, songs
    }
    
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
    
    var serverId: Int = { (Resolver.resolve() as SavedSettings).currentServerId }()
    
    private let folderArtist: FolderArtist?
    private let folderAlbum: FolderAlbum?
    private let parentFolderId: String
    private var loader: SubfolderLoader?
    
    private var metadata: FolderMetadata?
    private var folderAlbumIds = [String]()
    private var songIds = [String]()
        
    var hasLoaded: Bool { metadata != nil }
    var folderCount: Int { metadata?.folderCount ?? 0 }
    var songCount: Int { metadata?.songCount ?? 0 }
    var duration: Int { metadata?.duration ?? 0 }
    
    init(folderArtist: FolderArtist) {
        self.folderArtist = folderArtist
        self.folderAlbum = nil
        self.parentFolderId = folderArtist.id
        super.init(nibName: nil, bundle: nil)
    }
    
    init(folderAlbum: FolderAlbum) {
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
        
        loadFromCache()
        if hasLoaded {
            addHeader()
            addSectionIndex()
        } else {
            startLoad()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadData), name: Notifications.currentPlaylistIndexChanged)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadData), name: Notifications.songPlaybackStarted)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        cancelLoad()
        
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.currentPlaylistIndexChanged)
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.songPlaybackStarted)
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
            SongsHelper.playAll(serverId: serverId, folderId: parentFolderId)
        }, shuffleHandler: { [unowned self] in
            SongsHelper.shuffleAll(serverId: serverId, folderId: parentFolderId)
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
        HUD.show(closeHandler: cancelLoad)
        loader = SubfolderLoader(serverId: serverId, parentFolderId: parentFolderId) { [weak self] _, success, error in
            HUD.hide()
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
            } else if let error = error {
                if self.settings.isPopupsEnabled {
                    let message = "There was an error loading the album.\n\nError: \(error)"
                    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                    alert.addOKAction()
                    self.present(alert, animated: true, completion: nil)
                }
            }
            self.tableView.refreshControl?.endRefreshing()
        }
        loader?.startLoad()
    }
    
    func cancelLoad() {
        HUD.hide()
        loader?.cancelLoad()
        loader?.callback = nil
        loader = nil
        tableView.refreshControl?.endRefreshing()
    }
    
    override func tableCellModel(at indexPath: IndexPath) -> TableCellModel? {
        if let folderAlbum = folderAlbum(indexPath: indexPath) {
            return folderAlbum
        } else if let song = song(indexPath: indexPath) {
            return song
        }
        return nil
    }
}

extension FolderAlbumViewController: UITableViewConfiguration {
    private func folderAlbum(indexPath: IndexPath) -> FolderAlbum? {
        guard indexPath.section == SectionType.albums.rawValue && indexPath.row < folderAlbumIds.count else { return nil }
        return store.folderAlbum(serverId: serverId, id: folderAlbumIds[indexPath.row])
    }
    
    private func song(indexPath: IndexPath) -> Song? {
        guard indexPath.section == SectionType.songs.rawValue && indexPath.row < songIds.count else { return nil }
        return store.song(serverId: serverId, id: songIds[indexPath.row])
    }
    
    private func playSong(indexPath: IndexPath) -> Song? {
        guard indexPath.section == SectionType.songs.rawValue, indexPath.row < songIds.count else { return nil }
        return store.playSong(position: indexPath.row, songIds: songIds, serverId: serverId)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return SectionType.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == SectionType.albums.rawValue ? folderAlbumIds.count : songIds.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        if let folderAlbum = folderAlbum(indexPath: indexPath) {
            cell.show(downloaded: false, number: false, art: true, secondary: false, duration: false)
            cell.update(model: folderAlbum)
        } else if let song = song(indexPath: indexPath) {
            cell.update(song: song)
        }
        handleOfflineMode(cell: cell, at: indexPath)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let folderAlbum = folderAlbum(indexPath: indexPath) {
            let controller = FolderAlbumViewController(folderAlbum: folderAlbum)
            pushViewControllerCustom(controller)
        } else if let song = playSong(indexPath: indexPath), !song.isVideo {
            NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let model: TableCellModel? = folderAlbum(indexPath: indexPath) ?? song(indexPath: indexPath)
        return SwipeAction.downloadAndQueueConfig(model: model)
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let model: TableCellModel? = folderAlbum(indexPath: indexPath) ?? song(indexPath: indexPath)
        return contextMenuDownloadAndQueueConfig(model: model)
    }
}

extension UIImage {
    func with(insets: CGFloat) -> UIImage? {
        with(insets: UIEdgeInsets(top: insets, left: insets, bottom: insets, right: insets))
    }
    
    func with(insets: UIEdgeInsets) -> UIImage? {
        let cgSize = CGSize(width: size.width + (insets.left * scale) + (insets.right * scale),
                            height: size.height + (insets.top * scale) + (insets.bottom * scale))

        UIGraphicsBeginImageContextWithOptions(cgSize, false, scale)
        defer { UIGraphicsEndImageContext() }

        let origin = CGPoint(x: insets.left * scale, y: insets.top * scale)
        draw(at: origin)
        return UIGraphicsGetImageFromCurrentImageContext()?.withRenderingMode(renderingMode)
    }
}
