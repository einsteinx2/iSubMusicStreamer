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
    @Injected private var settings: Settings
    @Injected private var cache: Cache
    @Injected private var cacheQueue: CacheQueue
        
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
    
    @objc override func reloadTable() {
        downloadedTagAlbums = store.downloadedTagAlbums(downloadedTagArtist: downloadedTagArtist)
        super.reloadTable()
    }
    
    override func deleteItems(indexPaths: [IndexPath]) {
        HUD.show()
        DispatchQueue.userInitiated.async {
            for indexPath in indexPaths {
                _ = self.store.deleteDownloadedSongs(downloadedTagAlbum: self.downloadedTagAlbums[indexPath.row])
            }
            self.cache.findCacheSize()
            NotificationCenter.postOnMainThread(name: Notifications.cachedSongDeleted)
            if (!self.cacheQueue.isDownloading) {
                self.cacheQueue.start()
            }
            HUD.hide()
        }
    }
}

extension DownloadedTagArtistViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.show(cached: false, number: false, art: true, secondary: true, duration: false)
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
                self.downloadedTagAlbums[indexPath.row].queue()
                HUD.hide()
            }
        }, deleteHandler: {
            self.deleteItems(indexPaths: [indexPath])
        })
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return contextMenuDownloadAndQueueConfig(model: downloadedTagAlbums[indexPath.row])
    }
}
