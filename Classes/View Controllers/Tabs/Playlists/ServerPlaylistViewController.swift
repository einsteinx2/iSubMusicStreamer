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

@objc final class ServerPlaylistViewController: UITableViewController {
    @Injected private var store: Store
    
    private var serverPlaylistLoader: ServerPlaylistLoader?
    private var serverPlaylist: ServerPlaylist
    
    @objc init(serverPlaylist: ServerPlaylist) {
        self.serverPlaylist = serverPlaylist
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = serverPlaylist.name
        
        tableView.separatorStyle = .none
        tableView.rowHeight = Defines.rowHeight
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)
        tableView.reloadData()
        
        self.refreshControl = RefreshControl(handler: { [unowned self] in
            loadData()
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationItem.rightBarButtonItem = nil
        if Music.shared().showPlayerIcon {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "music.quarternote.3"), style: .plain, target: self, action: #selector(nowPlayingAction))
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelLoad()
    }
    
    @objc private func nowPlayingAction() {
        let controller = PlayerViewController()
        controller.hidesBottomBarWhenPushed = true
        pushCustom(controller)
    }
    
    private func loadData() {
        cancelLoad()
        let serverId = serverPlaylist.serverId
        let serverPlaylistId = serverPlaylist.id
        serverPlaylistLoader = ServerPlaylistLoader(serverPlaylistId: serverPlaylistId)
        serverPlaylistLoader?.callback = { [unowned self] (success, error) in
            EX2Dispatch.runInMainThreadAsync {
                if let error = error as NSError? {
                    if Settings.shared().isPopupsEnabled {
                        let message = "There was an error loading the playlist.\n\nError %\(error.code): \(error.localizedDescription)"
                        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                        present(alert, animated: true, completion: nil)
                    }
                } else {
                    // Reload the server playlist to get the updated loaded song count
                    if let serverPlaylist = store.serverPlaylist(serverId: serverId, id: serverPlaylistId) {
                        self.serverPlaylist = serverPlaylist
                    }
                    tableView.reloadData()
                }
                ViewObjects.shared().hideLoadingScreen()
                refreshControl?.endRefreshing()
            }
        }
        serverPlaylistLoader?.startLoad()
        ViewObjects.shared().showAlbumLoadingScreen(self.view, sender: self)
    }
    
    @objc func cancelLoad() {
        serverPlaylistLoader?.cancelLoad()
        serverPlaylistLoader?.callback = nil
        serverPlaylistLoader = nil
        ViewObjects.shared().hideLoadingScreen()
        self.refreshControl?.endRefreshing()
    }
    
    private func song(indexPath: IndexPath) -> Song? {
        return store.song(serverPlaylist: serverPlaylist, position: indexPath.row)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return serverPlaylist.loadedSongCount
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        cell.hideNumberLabel = false
        cell.hideCoverArt = false
        cell.hideDurationLabel = false
        cell.hideSecondaryLabel = false
        cell.number = indexPath.row + 1
        cell.update(model: song(indexPath: indexPath))
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        ViewObjects.shared().showLoadingScreenOnMainWindow(withMessage: nil)
        EX2Dispatch.runInBackgroundAsync { [unowned self] in
            let song = store.playSongFromServerPlaylist(serverId: serverPlaylist.serverId, serverPlaylistId: serverPlaylist.id, position: indexPath.row)
            
            EX2Dispatch.runInMainThreadAsync {
                ViewObjects.shared().hideLoadingScreen()
                if let song = song, !song.isVideo {
                    showPlayer()
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if let song = song(indexPath: indexPath) {
            return SwipeAction.downloadAndQueueConfig(model: song)
        }
        return nil
    }
}
