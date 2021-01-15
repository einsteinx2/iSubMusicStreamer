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

@objc final class NowPlayingViewController: UITableViewController {
    @Injected private var store: Store
    
    private var nowPlayingLoader: NowPlayingLoader?
    private var nowPlayingSongs = [NowPlayingSong]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Now Playing"
                
        self.refreshControl = RefreshControl(handler: { [unowned self] in
            loadData()
        })
        
        tableView.rowHeight = Defines.tallRowHeight
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(addURLRefBackButton), name: UIApplication.didBecomeActiveNotification.rawValue)
    }
    
    deinit {
        cancelLoad()
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        addURLRefBackButton()
        
        navigationItem.rightBarButtonItem = nil;
        if Music.shared().showPlayerIcon {
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "music.quarternote.3"), style: .plain, target: self, action: #selector(nowPlayingAction(sender:)))
        }
        
        loadData()
        Flurry.logEvent("NowPlayingTab")
    }
    
    private func loadData() {
        cancelLoad()
        ViewObjects.shared().showAlbumLoadingScreen(self.view, sender: self)
        nowPlayingLoader = NowPlayingLoader()
        nowPlayingLoader?.callback = { [unowned self] (success, error) in
            if let error = error as NSError? {
                if Settings.shared().isPopupsEnabled {
                    let message = "There was an error loading the now playing list.\n\nError \(error.code): \(error.localizedDescription)"
                    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    present(alert, animated: true, completion: nil)
                }
            } else {
                nowPlayingSongs = nowPlayingLoader?.nowPlayingSongs ?? []
                tableView.reloadData()
            }
            ViewObjects.shared().hideLoadingScreen()
            refreshControl?.endRefreshing()
            nowPlayingLoader = nil
        }
        nowPlayingLoader?.startLoad()
    }
    
    @objc func cancelLoad() {
        nowPlayingLoader?.cancelLoad()
        nowPlayingLoader?.callback = nil
        nowPlayingLoader = nil
        ViewObjects.shared().hideLoadingScreen()
        refreshControl?.endRefreshing()
    }
    
    @objc private func addURLRefBackButton() {
        if AppDelegate.shared().referringAppUrl != nil && AppDelegate.shared().mainTabBarController.selectedIndex != 4 {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: AppDelegate.shared(), action: #selector(AppDelegate.backToReferringApp))
        }
    }
    
    @objc private func nowPlayingAction(sender: Any?) {
        let controller = PlayerViewController()
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: true)
    }
    
    private func song(indexPath: IndexPath) -> Song? {
        let nowPlayingSong = nowPlayingSongs[indexPath.row]
        return store.song(serverId: nowPlayingSong.serverId, id: nowPlayingSong.songId)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return nowPlayingSongs.count
    }
    
    // NOTE: For some reason, in this controller and this controller only, it's ignoring the rowHeight property and this must be implemented. Maybe the XIB file?
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return Defines.tallRowHeight
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        cell.hideHeaderLabel = false
        cell.hideNumberLabel = true
        let nowPlayingSong = nowPlayingSongs[indexPath.row]
        let playTime = "\(nowPlayingSong.minutesAgo) \("min".pluralize(nowPlayingSong.minutesAgo)) ago"
        if nowPlayingSong.playerName.count > 0 {
            cell.headerText = "\(nowPlayingSong.username) @ \(nowPlayingSong.playerName) - \(playTime)"
        } else {
            cell.headerText = "\(nowPlayingSong.username) - \(playTime)"
        }
        cell.update(model: song(indexPath: indexPath))
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let song = song(indexPath: indexPath) {
            if let playingSong = store.playSong(position: indexPath.row, songs: [song]), !playingSong.isVideo {
                showPlayer()
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
