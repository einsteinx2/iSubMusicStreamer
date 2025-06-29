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
    @Injected private var settings: SavedSettings
    @Injected private var downloadsManager: DownloadsManager
    @Injected private var downloadQueue: DownloadQueue
    
    var serverId: Int { (Resolver.resolve() as SavedSettings).currentServerId }
    
    private var downloadedSongs = [DownloadedSong]()
    override var itemCount: Int { downloadedSongs.count }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Downloaded Songs"
        saveEditHeader.set(saveType: "Song", countType: "Song", isLargeCount: true)
    }

    override func reloadTable() {
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
            self.downloadsManager.findCacheSize()
            NotificationCenter.postOnMainThread(name: Notifications.downloadedSongDeleted)
            if (!self.downloadQueue.isDownloading) {
                self.downloadQueue.start()
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
            cell.update(song: song, number: false, downloaded: false, art: true)
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
        guard let model = store.song(downloadedSong: self.downloadedSongs[indexPath.row]) else { return nil }
        return SwipeAction.downloadQueueAndDeleteConfig(model: model) {
            self.deleteItems(indexPaths: [indexPath])
        }
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let model = store.song(downloadedSong: self.downloadedSongs[indexPath.row]) else { return nil }
        // TODO: Support custom delete closure like the swipe actions
        return contextMenuDownloadAndQueueConfig(model: model)
    }
}
