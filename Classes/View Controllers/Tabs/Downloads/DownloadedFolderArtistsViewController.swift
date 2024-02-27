//
//  DownloadedFolderArtistsViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import SnapKit
import CocoaLumberjackSwift

final class DownloadedFolderArtistsViewController: AbstractDownloadsViewController {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
    @Injected private var downloadsManager: DownloadsManager
    @Injected private var downloadQueue: DownloadQueue
        
    var serverId: Int = { (Resolver.resolve() as SavedSettings).currentServerId }()
    
    private var downloadedFolderArtists = [DownloadedFolderArtist]()
    override var itemCount: Int { downloadedFolderArtists.count }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Downloaded Folders"
        saveEditHeader.set(saveType: "Folder", countType: "Folder", isLargeCount: true)
    }
    
    @objc override func reloadTable() {
        downloadedFolderArtists = store.downloadedFolderArtists(serverId: serverId)
        super.reloadTable()
        addOrRemoveSaveEditHeader()
    }
    
    override func deleteItems(indexPaths: [IndexPath]) {
        HUD.show()
        DispatchQueue.userInitiated.async {
            defer { HUD.hide() }
            for indexPath in indexPaths {
                _ = self.store.deleteDownloadedSongs(downloadedFolderArtist: self.downloadedFolderArtists[indexPath.row])
            }
            self.downloadsManager.findCacheSize()
            NotificationCenter.postOnMainThread(name: Notifications.downloadedSongDeleted)
            if (!self.downloadQueue.isDownloading) {
                self.downloadQueue.start()
            }
        }
    }
    
    override func tableCellModel(at indexPath: IndexPath) -> TableCellModel? {
        guard indexPath.row < downloadedFolderArtists.count else { return nil }
        return downloadedFolderArtists[indexPath.row]
    }
}

extension DownloadedFolderArtistsViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.show(downloaded: false, number: false, art: false, secondary: true, duration: false)
        cell.update(model: downloadedFolderArtists[indexPath.row])
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)
        if !isEditing {
            let controller = DownloadedFolderAlbumViewController(folderArtist: downloadedFolderArtists[indexPath.row])
            pushViewControllerCustom(controller)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        SwipeAction.downloadQueueAndDeleteConfig(downloadHandler: nil, queueHandler: {
            HUD.show()
            DispatchQueue.userInitiated.async {
                defer { HUD.hide() }
                self.downloadedFolderArtists[indexPath.row].queue()
            }
        }, deleteHandler: {
            self.deleteItems(indexPaths: [indexPath])
        })
    }
}
