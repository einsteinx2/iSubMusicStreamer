//
//  LocalPlaylistViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import Resolver

final class ServerPlaylistViewController: UIViewController {
    @Injected private var store: Store
    @Injected private var settings: Settings
        
    private var serverPlaylistLoader: ServerPlaylistLoader?
    private var serverPlaylist: ServerPlaylist
    
    private let tableView = UITableView()
    
    init(serverPlaylist: ServerPlaylist) {
        self.serverPlaylist = serverPlaylist
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = serverPlaylist.name
        setupDefaultTableView(tableView)
        tableView.refreshControl = RefreshControl { [unowned self] in
            loadData()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelLoad()
    }
    
    private func loadData() {
        cancelLoad()
        HUD.show(closeHandler: cancelLoad)
        serverPlaylistLoader = ServerPlaylistLoader(serverPlaylist: serverPlaylist)
        serverPlaylistLoader?.callback = { [unowned self] _, success, error in
            HUD.hide()
            tableView.refreshControl?.endRefreshing()
            
            if let error = error {
                if settings.isPopupsEnabled {
                    let message = "There was an error loading the playlist.\n\nError: \(error)"
                    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                    alert.addOKAction()
                    present(alert, animated: true, completion: nil)
                }
            } else {
                // Reload the server playlist to get the updated loaded song count
                if let serverPlaylist = store.serverPlaylist(serverId: serverPlaylist.serverId, id: serverPlaylist.id) {
                    self.serverPlaylist = serverPlaylist
                }
                tableView.reloadData()
            }
        }
        serverPlaylistLoader?.startLoad()
    }
    
    @objc func cancelLoad() {
        HUD.hide()
        serverPlaylistLoader?.cancelLoad()
        serverPlaylistLoader?.callback = nil
        serverPlaylistLoader = nil
        self.tableView.refreshControl?.endRefreshing()
    }
}
 
extension ServerPlaylistViewController: UITableViewConfiguration {
    private func song(indexPath: IndexPath) -> Song? {
        return store.song(serverPlaylist: serverPlaylist, position: indexPath.row)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return serverPlaylist.loadedSongCount
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.show(cached: true, number: true, art: true, secondary: true, duration: true)
        cell.number = indexPath.row + 1
        cell.update(model: song(indexPath: indexPath))
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        HUD.show()
        DispatchQueue.userInitiated.async { [unowned self] in
            defer { HUD.hide() }
            let song = store.playSongFromServerPlaylist(serverId: serverPlaylist.serverId, serverPlaylistId: serverPlaylist.id, position: indexPath.row)
            if let song = song, !song.isVideo {
                NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if let song = song(indexPath: indexPath) {
            return SwipeAction.downloadAndQueueConfig(model: song)
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return contextMenuDownloadAndQueueConfig(model: song(indexPath: indexPath))
    }
}
