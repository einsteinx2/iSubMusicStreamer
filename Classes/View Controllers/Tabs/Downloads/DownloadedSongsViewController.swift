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
    @Injected private var cache: Cache
    @Injected private var cacheQueue: CacheQueue
    
    var serverId: Int { Settings.shared().currentServerId }
    
    private var downloadedSongs = [DownloadedSong]()
    override var itemCount: Int { downloadedSongs.count }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Downloaded Songs"
        saveEditHeader.set(saveType: "Song", countType: "Song", isLargeCount: true)
    }

    @objc override func reloadTable() {
        downloadedSongs = store.downloadedSongs(serverId: serverId)
        super.reloadTable()
        addOrRemoveSaveEditHeader()
    }
    
    override func deleteItems(indexPaths: [IndexPath]) {
        HUD.show()
        DispatchQueue.userInitiated.async {
            defer { HUD.hide() }
            for indexPath in indexPaths {
                _ = self.store.delete(downloadedSong: self.downloadedSongs[indexPath.row])
            }
            self.cache.findCacheSize()
            NotificationCenter.postOnMainThread(name: Notifications.cachedSongDeleted)
            if (!self.cacheQueue.isDownloading) {
                self.cacheQueue.start()
            }
        }
    }
    
    override func tableCellModel(at indexPath: IndexPath) -> TableCellModel? {
        guard indexPath.row < downloadedSongs.count else { return nil }
        return store.song(downloadedSong: downloadedSongs[indexPath.row])
    }
}

extension DownloadedSongsViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        if let song = store.song(downloadedSong: downloadedSongs[indexPath.row]) {
            cell.update(song: song, number: false, cached: false, art: true)
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)
        if !isEditing, let song = store.playSong(position: indexPath.row, downloadedSongs: downloadedSongs), !song.isVideo {
            NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        SwipeAction.downloadQueueAndDeleteConfig(downloadHandler: nil, queueHandler: {
            HUD.show()
            DispatchQueue.userInitiated.async {
                defer { HUD.hide() }
                self.store.song(downloadedSong: self.downloadedSongs[indexPath.row])?.queue()
            }
        }, deleteHandler: {
            self.deleteItems(indexPaths: [indexPath])
        })
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let song = store.song(downloadedSong: downloadedSongs[indexPath.row])
        return contextMenuDownloadAndQueueConfig(model: song)
    }
}
