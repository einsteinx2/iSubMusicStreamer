//
//  DownloadedTagArtistViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/20/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import SnapKit
import CocoaLumberjackSwift

// TODO: Make sure to call the getArtist API for all downloaded songs or they won't show up here
final class DownloadedTagArtistViewController: AbstractDownloadsViewController {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
    @Injected private var downloadsManager: DownloadsManager
    @Injected private var downloadQueue: DownloadQueue
        
    private let downloadedTagArtist: DownloadedTagArtist
    private var downloadedTagAlbums = [DownloadedTagAlbum]()
    override var itemCount: Int { downloadedTagAlbums.count }
    
    init(downloadedTagArtist: DownloadedTagArtist) {
        self.downloadedTagArtist = downloadedTagArtist
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = downloadedTagArtist.name
    }
    
    override func reloadTable() {
        downloadedTagAlbums = store.downloadedTagAlbums(downloadedTagArtist: downloadedTagArtist)
        super.reloadTable()
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

extension DownloadedTagArtistViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.show(downloaded: false, number: false, art: true, secondary: true, duration: false)
        cell.update(model: downloadedTagAlbums[indexPath.row])
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let controller = DownloadedTagAlbumViewController(downloadedTagAlbum: downloadedTagAlbums[indexPath.row])
        pushViewControllerCustom(controller)
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
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return contextMenuDownloadAndQueueConfig(model: downloadedTagAlbums[indexPath.row])
    }
}
