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
    @Injected private var settings: Settings
        
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
    
    @objc override func reloadTable() {
        downloadedSongs = store.downloadedSongs(downloadedTagAlbum: downloadedTagAlbum)
        super.reloadTable()
    }
}

extension DownloadedTagAlbumViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        if let song = store.song(downloadedSong: downloadedSongs[indexPath.row]) {
            cell.update(song: song, cached: false)
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let song = store.playSong(position: indexPath.row, downloadedSongs: downloadedSongs), !song.isVideo {
            NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // TODO: implement this
        return nil
    }
}
