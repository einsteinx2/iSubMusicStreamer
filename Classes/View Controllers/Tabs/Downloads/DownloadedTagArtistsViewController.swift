//
//  DownloadedTagArtistsViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import SnapKit
import CocoaLumberjackSwift

// TODO: Make sure to call the getArtist API for all downloaded songs or they won't show up here
final class DownloadedTagArtistsViewController: AbstractDownloadsViewController {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
    @Injected private var downloadsManager: DownloadsManager
    @Injected private var downloadQueue: DownloadQueue
    
    var serverId: Int = { (Resolver.resolve() as SavedSettings).currentServerId }()
        
    private var downloadedTagArtists = [DownloadedTagArtist]()
    override var itemCount: Int { downloadedTagArtists.count }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Downloaded Artists"
        saveEditHeader.set(saveType: "Artist", countType: "Artist", isLargeCount: true)
    }
    
    @objc override func reloadTable() {
        downloadedTagArtists = store.downloadedTagArtists(serverId: serverId)
        super.reloadTable()
        addOrRemoveSaveEditHeader()
    }
    
    override func deleteItems(indexPaths: [IndexPath]) {
        HUD.show()
        DispatchQueue.userInitiated.async {
            defer { HUD.hide() }
            for indexPath in indexPaths {
                _ = self.store.deleteDownloadedSongs(downloadedTagArtist: self.downloadedTagArtists[indexPath.row])
            }
            self.downloadsManager.findCacheSize()
            NotificationCenter.postOnMainThread(name: Notifications.downloadedSongDeleted)
            if (!self.downloadQueue.isDownloading) {
                self.downloadQueue.start()
            }
        }
    }
    
    override func tableCellModel(at indexPath: IndexPath) -> TableCellModel? {
        guard indexPath.row < downloadedTagArtists.count else { return nil }
        return downloadedTagArtists[indexPath.row]
    }
}

extension DownloadedTagArtistsViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.show(downloaded: false, number: false, art: true, secondary: true, duration: false)
        cell.update(model: downloadedTagArtists[indexPath.row])
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)
        if !isEditing {
            let controller = DownloadedTagArtistViewController(downloadedTagArtist: downloadedTagArtists[indexPath.row])
            pushViewControllerCustom(controller)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        SwipeAction.downloadQueueAndDeleteConfig(downloadHandler: nil, queueHandler: {
            HUD.show()
            DispatchQueue.userInitiated.async {
                defer { HUD.hide() }
                self.downloadedTagArtists[indexPath.row].queue()
            }
        }, deleteHandler: {
            self.deleteItems(indexPaths: [indexPath])
        })
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return contextMenuDownloadAndQueueConfig(model: downloadedTagArtists[indexPath.row])
    }
}
