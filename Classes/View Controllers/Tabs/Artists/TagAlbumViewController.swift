//
//  TagAlbumViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import Resolver

final class TagAlbumViewController: UIViewController {
    @Injected private var store: Store
    
    var serverId = Settings.shared().currentServerId
    
    private let tagAlbum: TagAlbum
    private var loader: TagAlbumLoader?
    private var songIds = [Int]()
    
    private let tableView = UITableView()
    
    init(tagAlbum: TagAlbum) {
        self.tagAlbum = tagAlbum
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
        title = tagAlbum.name
        
        setupDefaultTableView(tableView)
        tableView.refreshControl = RefreshControl { [unowned self] in
            startLoad()
        }
        
        if songIds.count == 0 {
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
        guard songIds.count > 0 else {
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
        let albumHeader = AlbumTableViewHeader(tagAlbum: tagAlbum)
        headerView.addSubview(albumHeader)
        albumHeader.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
        }
        
        // Create the play all and shuffle buttons and constrain to the container view
        let playAllAndShuffleHeader = PlayAllAndShuffleHeader(playAllHandler: { [unowned self] in
            SongLoader.playAll(tagAlbumId: tagAlbum.id)
        }, shuffleHandler: { [unowned self] in
            SongLoader.shuffleAll(tagAlbumId: tagAlbum.id)
        })
        headerView.addSubview(playAllAndShuffleHeader)
        playAllAndShuffleHeader.snp.makeConstraints { make in
            make.top.equalTo(albumHeader.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        // Force re-layout using the constraints
        tableView.tableHeaderView?.layoutIfNeeded()
        tableView.tableHeaderView = tableView.tableHeaderView
    }
    
    @objc private func reloadData() {
        tableView.reloadData()
    }
    
    private func loadFromCache() {
        songIds = store.songIds(serverId: serverId, tagAlbumId: tagAlbum.id)
    }
    
    func startLoad() {
        ViewObjects.shared().showAlbumLoadingScreen(view, sender: self)
        loader = TagAlbumLoader(tagAlbumId: tagAlbum.id) { [weak self] success, error in
            guard let self = self else { return }
            
            self.songIds = self.loader?.songIds ?? []
            self.loader = nil
            
            if success {
                self.tableView.reloadData()
                self.addHeader()
            } else if let error = error as NSError? {
                if Settings.shared().isPopupsEnabled {
                    let message = "There was an error loading the album.\n\nError \(error.code): \(error.localizedDescription)"
                    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                    alert.addCancelAction(title: "OK")
                    self.present(alert, animated: true, completion: nil)
                }
            }
            ViewObjects.shared().hideLoadingScreen()
            self.tableView.refreshControl?.endRefreshing()
        }
        loader?.startLoad()
    }
    
    func cancelLoad() {
        loader?.cancelLoad()
        loader?.callback = nil
        loader = nil
        
        tableView.refreshControl?.endRefreshing()
        ViewObjects.shared().hideLoadingScreen()
    }
}

extension TagAlbumViewController: UITableViewConfiguration {
    private func song(indexPath: IndexPath) -> Song? {
        guard indexPath.row < songIds.count else { return nil }
        return store.song(serverId: serverId, id: songIds[indexPath.row])
    }
    
    private func playSong(indexPath: IndexPath) -> Song? {
        guard indexPath.row < songIds.count else { return nil }
        return store.playSong(position: indexPath.row, songIds: songIds, serverId: serverId)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songIds.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        if let song = song(indexPath: indexPath) {
            var showNumber = false
            if song.track > 0 {
                showNumber = true
                cell.number = song.track
            }
            cell.show(cached: true, number: showNumber, art: false, secondary: true, duration: true)
            cell.update(model: song)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let song = playSong(indexPath: indexPath), !song.isVideo {
            showPlayer()
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if let song = song(indexPath: indexPath), !song.isVideo {
            return SwipeAction.downloadAndQueueConfig(model: song)
        }
        return nil
    }
}
