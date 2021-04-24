//
//  TagArtistViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver

final class TagArtistViewController: UIViewController {
    @Injected private var store: Store
    @Injected private var settings: Settings
    
    var serverId: Int { Settings.shared().currentServerId }
    
    private let tagArtist: TagArtist
    private var loader: TagArtistLoader?
    private var tagAlbumIds = [String]()
    
    private let tableView = UITableView()
    
    init(tagArtist: TagArtist) {
        self.tagArtist = tagArtist
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
        title = tagArtist.name
        
        setupDefaultTableView(tableView)
        tableView.refreshControl = RefreshControl { [unowned self] in
            startLoad()
        }
        
        if tagAlbumIds.count == 0 {
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
    
    @objc private func reloadData() {
        tableView.reloadData()
    }
    
    private func loadFromCache() {
        tagAlbumIds = store.tagAlbumIds(serverId: serverId, tagArtistId: tagArtist.id, orderBy: .year)
    }
    
    func startLoad() {
        HUD.show(closeHandler: cancelLoad)
        loader = TagArtistLoader(serverId: serverId, tagArtistId: tagArtist.id) { [weak self] _, success, error in
            HUD.hide()
            guard let self = self else { return }
            
            self.tagAlbumIds = self.loader?.tagAlbumIds ?? []
            self.loader = nil
            
            if success {
                self.tableView.reloadData()
//                self.addHeaderAndIndex()
            } else if let error = error {
                if self.settings.isPopupsEnabled {
                    let message = "There was an error loading the artist.\n\nError: \(error)"
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
}

extension TagArtistViewController: UITableViewConfiguration {
    private func tagAlbum(indexPath: IndexPath) -> TagAlbum? {
        guard indexPath.row < tagAlbumIds.count else { return nil }
        return store.tagAlbum(serverId: serverId, id: tagAlbumIds[indexPath.row])
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tagAlbumIds.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.show(cached: false, number: false, art: true, secondary: true, duration: false)
        cell.update(model: tagAlbum(indexPath: indexPath))
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let tagAlbum = tagAlbum(indexPath: indexPath) {
            pushViewControllerCustom(TagAlbumViewController(tagAlbum: tagAlbum))
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return SwipeAction.downloadAndQueueConfig(model: tagAlbum(indexPath: indexPath))
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return contextMenuDownloadAndQueueConfig(model: tagAlbum(indexPath: indexPath))
    }
}
