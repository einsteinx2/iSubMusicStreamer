//
//  DownloadedTagAlbumsViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import SnapKit
import CocoaLumberjackSwift

// TODO: Make sure to call the getAlbum API for all downloaded songs or they won't show up here
final class DownloadedTagAlbumsViewController: AbstractDownloadsViewController {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
    @Injected private var downloadsManager: DownloadsManager
    @Injected private var downloadQueue: DownloadQueue
    
    var serverId: Int = { SavedSettings.shared().currentServerId }()
        
    private var downloadedTagAlbums = [DownloadedTagAlbum]()
    override var itemCount: Int { downloadedTagAlbums.count }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Downloaded Albums"
        saveEditHeader.set(saveType: "Album", countType: "Album", isLargeCount: true)
    }
    
    @objc override func reloadTable() {
        downloadedTagAlbums = store.downloadedTagAlbums(serverId: serverId)
        super.reloadTable()
        addOrRemoveSaveEditHeader()
    }
    
    override func deleteItems(indexPaths: [IndexPath]) {
        HUD.show()
        DispatchQueue.userInitiated.async {
            defer { HUD.hide() }
            for indexPath in indexPaths {
                _ = self.store.deleteDownloadedSongs(downloadedTagAlbum: self.downloadedTagAlbums[indexPath.row])
            }
            self.downloadsManager.findCacheSize()
            NotificationCenter.postOnMainThread(name: Notifications.downloadedSongDeleted)
            if (!self.downloadQueue.isDownloading) {
                self.downloadQueue.start()
            }
        }
    }
    
    override func tableCellModel(at indexPath: IndexPath) -> TableCellModel? {
        guard indexPath.row < downloadedTagAlbums.count else { return nil }
        return downloadedTagAlbums[indexPath.row]
    }
}

extension DownloadedTagAlbumsViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.show(downloaded: false, number: false, art: true, secondary: true, duration: false)
        cell.update(model: downloadedTagAlbums[indexPath.row])
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)
        if !isEditing {
            let controller = DownloadedTagAlbumViewController(downloadedTagAlbum: downloadedTagAlbums[indexPath.row])
            pushViewControllerCustom(controller)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        SwipeAction.downloadQueueAndDeleteConfig(downloadHandler: nil, queueHandler: {
            HUD.show()
            DispatchQueue.userInitiated.async {
                defer { HUD.hide() }
                self.downloadedTagAlbums[indexPath.row].queue()
            }
        }, deleteHandler: {
            self.deleteItems(indexPaths: [indexPath])
        })
    }
}
