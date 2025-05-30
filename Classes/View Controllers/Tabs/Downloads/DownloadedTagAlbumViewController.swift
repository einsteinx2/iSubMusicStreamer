//
//  DownloadedTagAlbumViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/20/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import SnapKit
import CocoaLumberjackSwift

// TODO: Make sure to call the getAlbum API for all downloaded songs or they won't show up here
final class DownloadedTagAlbumViewController: AbstractDownloadsViewController {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
    @Injected private var downloadsManager: DownloadsManager
    @Injected private var downloadQueue: DownloadQueue
        
    private let downloadedTagAlbum: DownloadedTagAlbum
    private var downloadedSongs = [DownloadedSong]()
    override var itemCount: Int { downloadedSongs.count }
    
    init(downloadedTagAlbum: DownloadedTagAlbum) {
        self.downloadedTagAlbum = downloadedTagAlbum
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = downloadedTagAlbum.name
    }
    
    override func reloadTable() {
        downloadedSongs = store.downloadedSongs(downloadedTagAlbum: downloadedTagAlbum)
        super.reloadTable()
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

extension DownloadedTagAlbumViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        if let song = store.song(downloadedSong: downloadedSongs[indexPath.row]) {
            cell.update(song: song, downloaded: false)
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let song = store.playSong(position: indexPath.row, downloadedSongs: downloadedSongs), !song.isVideo {
            NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let model = store.song(downloadedSong: downloadedSongs[indexPath.row]) else { return nil }
        return SwipeAction.downloadQueueAndDeleteConfig(model: model) {
            self.deleteItems(indexPaths: [indexPath])
        }
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let model = store.song(downloadedSong: downloadedSongs[indexPath.row]) else { return nil }
        return contextMenuDownloadAndQueueConfig(model: model)
    }
}
