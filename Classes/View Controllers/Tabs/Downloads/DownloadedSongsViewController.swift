//
//  DownloadedSongsViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import SnapKit
import CocoaLumberjackSwift

final class DownloadedSongsViewController: AbstractDownloadsViewController {
    @Injected private var store: Store
    @Injected private var settings: Settings
    
    var serverId: Int { Settings.shared().currentServerId }
    
    private var downloadedSongs = [DownloadedSong]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Downloaded Songs"
    }

    @objc override func reloadTable() {
        downloadedSongs = store.downloadedSongs(serverId: serverId)
        super.reloadTable()
    }
}

extension DownloadedSongsViewController: UITableViewConfiguration {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return downloadedSongs.count
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        if let song = store.song(downloadedSong: downloadedSongs[indexPath.row]) {
            cell.update(song: song)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let song = store.playSong(position: indexPath.row, downloadedSongs: downloadedSongs), !song.isVideo {
            NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // TODO: implement this
        return nil
    }
}
