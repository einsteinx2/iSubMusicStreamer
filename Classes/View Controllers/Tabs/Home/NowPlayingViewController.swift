//
//  NowPlayingViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import SnapKit

final class NowPlayingViewController: CustomUITableViewController {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
    @Injected private var analytics: Analytics
    
    var serverId: Int { (Resolver.resolve() as SavedSettings).currentServerId }
        
    private var loadingTask: Task<Void, Never>?
    private var nowPlayingSongs = [NowPlayingSong]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Colors.background
        title = "Now Playing"
        setupDefaultTableView(tableView)
        tableView.rowHeight = Defines.tallRowHeight
        tableView.refreshControl = RefreshControl { [unowned self] in
            loadData()
        }
    }
    
    deinit {
        cancelLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
        analytics.log(event: .nowPlayingTab)
    }
    
    private func loadData() {
        loadingTask?.cancel()
        loadingTask = Task {
            do {
                HUD.show(closeHandler: cancelLoad)
                defer {
                    HUD.hide()
                    tableView.refreshControl?.endRefreshing()
                }
                
                nowPlayingSongs = try await AsyncNowPlayingLoader(serverId: serverId).load()
                tableView.reloadData()
            } catch {
                if settings.isPopupsEnabled, !error.isCanceled {
                    let message = "There was an error loading the now playing list.\n\nError: \(error)"
                    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                    alert.addOKAction()
                    present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    func cancelLoad() {
        HUD.hide()
        loadingTask?.cancel()
        loadingTask = nil
        tableView.refreshControl?.endRefreshing()
    }
    
    private func song(indexPath: IndexPath) -> Song? {
        let nowPlayingSong = nowPlayingSongs[indexPath.row]
        return store.song(serverId: nowPlayingSong.serverId, id: nowPlayingSong.songId)
    }
    
    override func tableCellModel(at indexPath: IndexPath) -> TableCellModel? {
        return song(indexPath: indexPath)
    }
}

extension NowPlayingViewController: UITableViewConfiguration {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return nowPlayingSongs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        let nowPlayingSong = nowPlayingSongs[indexPath.row]
        let playTime = "\(nowPlayingSong.minutesAgo) \("min".pluralize(amount: nowPlayingSong.minutesAgo)) ago"
        if nowPlayingSong.playerName.count > 0 {
            cell.headerText = "\(nowPlayingSong.username) @ \(nowPlayingSong.playerName) - \(playTime)"
        } else {
            cell.headerText = "\(nowPlayingSong.username) - \(playTime)"
        }
        cell.show(downloaded: true, number: false, art: true, secondary: true, duration: true, header: true)
        cell.update(model: song(indexPath: indexPath))
        handleOfflineMode(cell: cell, at: indexPath)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let song = song(indexPath: indexPath), let playingSong = store.playSong(position: indexPath.row, songs: [song]), !playingSong.isVideo {
            NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if let song = song(indexPath: indexPath) {
            return SwipeAction.downloadAndQueueConfig(model: song)
        }
        return nil
    }
}
