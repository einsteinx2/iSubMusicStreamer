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

extension DownloadedTagAlbumViewController: UITableViewConfiguration {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return downloadedSongs.count
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        if let song = store.song(downloadedSong: downloadedSongs[indexPath.row]) {
            var showNumber = false
            if song.track > 0 {
                showNumber = true
                cell.number = song.track
            }
            cell.show(cached: true, number: showNumber, art: true, secondary: true, duration: true)
            cell.update(model: song)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let song = store.playSong(position: indexPath.row, downloadedSongs: downloadedSongs), !song.isVideo {
            showPlayer()
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // TODO: implement this
        return nil
    }
}
