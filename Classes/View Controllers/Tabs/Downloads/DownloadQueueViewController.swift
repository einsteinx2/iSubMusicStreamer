//
//  DownloadQueueViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 2/17/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import SnapKit
import CocoaLumberjackSwift

final class DownloadQueueViewController: AbstractDownloadsViewController {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
    @Injected private var downloadsManager: DownloadsManager
    @Injected private var downloadQueue: DownloadQueue
    
    var serverId: Int { (Resolver.resolve() as SavedSettings).currentServerId }
    
    override var itemCount: Int { store.downloadQueueCount() ?? 0 }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Download Queue"
        saveEditHeader.set(saveType: "Song", countType: "Song", isLargeCount: true)
        tableView.rowHeight = Defines.tallRowHeight
    }
    
    override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadTable), name: Notifications.downloadQueueSongAdded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadTable), name: Notifications.downloadQueueSongRemoved)
    }

    override func reloadTable() {
        super.reloadTable()
        addOrRemoveSaveEditHeader()
    }
    
    override func deleteItems(indexPaths: [IndexPath]) {
        HUD.show()
        DispatchQueue.userInitiated.async {
            defer { HUD.hide() }
            var songs = [Song]()
            for indexPath in indexPaths {
                if let song = self.store.songFromDownloadQueue(position: indexPath.row) {
                    songs.append(song)
                }
            }
            for song in songs {
                _ = self.store.removeFromDownloadQueue(song: song)
            }
            if (!self.downloadQueue.isDownloading) {
                self.downloadQueue.start()
            }
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    override func tableCellModel(at indexPath: IndexPath) -> TableCellModel? {
        return store.songFromDownloadQueue(position: indexPath.row)
    }
}

extension DownloadQueueViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        if let song = store.songFromDownloadQueue(position: indexPath.row) {
            cell.update(song: song, number: false, downloaded: false, art: true)
            cell.hideHeaderLabel = false
            if indexPath.row == 0 {
                cell.headerText = "Downloading!"
            } else {
                cell.headerText = "Waiting..."
            }
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)
//        if !isEditing, let song = store.playSong(position: indexPath.row, downloadedSongs: downloadedSongs), !song.isVideo {
//            NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
//        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let model = self.store.songFromDownloadQueue(position: indexPath.row) else { return nil }
        return SwipeAction.downloadQueueAndDeleteConfig(model: model) {
            self.deleteItems(indexPaths: [indexPath])
        }
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let model = store.songFromDownloadQueue(position: indexPath.row) else { return nil }
        return contextMenuDownloadAndQueueConfig(model: model)
    }
}
