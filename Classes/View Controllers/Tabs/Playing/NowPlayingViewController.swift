//
//  NowPlayingViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import InflectorKit
import SnapKit

final class NowPlayingViewController: UIViewController {
    @Injected private var store: Store
    @Injected private var settings: Settings
    
    var serverId: Int { Settings.shared().currentServerId }
    
    private let tableView = UITableView()
    
    private var nowPlayingLoader: NowPlayingLoader?
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
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(addURLRefBackButton), name: UIApplication.didBecomeActiveNotification)
    }
    
    deinit {
        cancelLoad()
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        addURLRefBackButton()
        addShowPlayerButton()
        
        loadData()
        Flurry.logEvent("NowPlayingTab")
    }
    
    private func loadData() {
        cancelLoad()
        HUD.show(closeHandler: cancelLoad)
        nowPlayingLoader = NowPlayingLoader(serverId: serverId)
        nowPlayingLoader?.callback = { [unowned self] (success, error) in
            if let error = error {
                if settings.isPopupsEnabled {
                    let message = "There was an error loading the now playing list.\n\nError \(error.code): \(error.localizedDescription)"
                    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                    alert.addOKAction()
                    present(alert, animated: true, completion: nil)
                }
            } else {
                nowPlayingSongs = nowPlayingLoader?.nowPlayingSongs ?? []
                tableView.reloadData()
            }
            HUD.hide()
            tableView.refreshControl?.endRefreshing()
            nowPlayingLoader = nil
        }
        nowPlayingLoader?.startLoad()
    }
    
    @objc func cancelLoad() {
        nowPlayingLoader?.cancelLoad()
        nowPlayingLoader?.callback = nil
        nowPlayingLoader = nil
        HUD.hide()
        tableView.refreshControl?.endRefreshing()
    }
    
    private func song(indexPath: IndexPath) -> Song? {
        let nowPlayingSong = nowPlayingSongs[indexPath.row]
        return store.song(serverId: nowPlayingSong.serverId, id: nowPlayingSong.songId)
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
        cell.hideHeaderLabel = false
        cell.show(cached: true, number: false, art: true, secondary: true, duration: true)
        cell.update(model: song(indexPath: indexPath))
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let song = song(indexPath: indexPath) {
            if let playingSong = store.playSong(position: indexPath.row, songs: [song]), !playingSong.isVideo {
                showPlayer()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if let song = song(indexPath: indexPath) {
            return SwipeAction.downloadAndQueueConfig(model: song)
        }
        return nil
    }
}
