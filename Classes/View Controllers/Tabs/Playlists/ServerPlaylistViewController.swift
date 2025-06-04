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

final class ServerPlaylistViewController: CustomUITableViewController {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
        
    private var loaderTask: Task<Void, Never>?
    private var serverPlaylist: ServerPlaylist
        
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
        loaderTask?.cancel()
        loaderTask = Task {
            do {
                HUD.show(closeHandler: cancelLoad)
                defer {
                    HUD.hide()
                    tableView.refreshControl?.endRefreshing()
                }
                
                // Reload the server playlist to get the updated loaded song count
                serverPlaylist = try await AsyncServerPlaylistLoader(serverPlaylist: serverPlaylist).load()
                tableView.reloadData()
            } catch {
                if settings.isPopupsEnabled && !error.isCanceled {
                    let message = "There was an error loading the playlist.\n\nError: \(error)"
                    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                    alert.addOKAction()
                    present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    func cancelLoad() {
        // TODO: Double check if we still need to call HUD.hide() and other things we call in defer blocks, I think it's not since they should be called after canceling, but may be delayed so bad UX unless we call it directly here
        HUD.hide()
        loaderTask?.cancel()
        loaderTask = nil
        tableView.refreshControl?.endRefreshing()
    }
    
    override func tableCellModel(at indexPath: IndexPath) -> TableCellModel? {
        return song(indexPath: indexPath)
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
        cell.show(downloaded: true, number: true, art: true, secondary: true, duration: true)
        cell.number = indexPath.row + 1
        cell.update(model: song(indexPath: indexPath))
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        HUD.show()
        DispatchQueue.userInitiated.async { [unowned self] in
            defer { HUD.hide() }
            let song = store.playSongFromServerPlaylist(serverId: serverPlaylist.serverId, serverPlaylistId: serverPlaylist.id, position: indexPath.row)
            if let song, !song.isVideo {
                NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let model = song(indexPath: indexPath) else { return nil }
        return SwipeAction.downloadAndQueueConfig(model: model)
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let model = song(indexPath: indexPath) else { return nil }
        return contextMenuDownloadAndQueueConfig(model: model)
    }
}
