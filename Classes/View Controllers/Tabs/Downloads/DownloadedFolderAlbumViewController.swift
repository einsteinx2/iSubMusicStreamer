//
//  DownloadedFolderAlbumViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/20/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import SnapKit
import CocoaLumberjackSwift

final class DownloadedFolderAlbumViewController: AbstractDownloadsViewController {
    @Injected private var store: Store
    @Injected private var settings: Settings
    
    private let serverId: Int
    private let level: Int
    private let parentPathComponent: String
    private let downloadedFolderArtist: DownloadedFolderArtist?
    private let downloadedFolderAlbum: DownloadedFolderAlbum?
        
    private var downloadedFolderAlbums = [DownloadedFolderAlbum]()
    private var downloadedSongs = [DownloadedSong]()
    
    init(folderArtist: DownloadedFolderArtist) {
        self.downloadedFolderArtist = folderArtist
        self.downloadedFolderAlbum = nil
        self.serverId = folderArtist.serverId
        self.level = 1
        self.parentPathComponent = folderArtist.name
//        self.parentFolderId = folderArtist.id
        super.init(nibName: nil, bundle: nil)
    }
    
    init(folderAlbum: DownloadedFolderAlbum) {
        self.downloadedFolderArtist = nil
        self.downloadedFolderAlbum = folderAlbum
        self.serverId = folderAlbum.serverId
        self.level = folderAlbum.level + 1
        self.parentPathComponent = folderAlbum.name
//        self.parentFolderId = folderAlbum.id
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = parentPathComponent
    }
    
    @objc override func reloadTable() {
        downloadedFolderAlbums = store.downloadedFolderAlbums(serverId: serverId, level: level, parentPathComponent: parentPathComponent)
        downloadedSongs = store.downloadedSongs(serverId: serverId, level: level, parentPathComponent: parentPathComponent)
        super.reloadTable()
    }
}

extension DownloadedFolderAlbumViewController: UITableViewConfiguration {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? downloadedFolderAlbums.count : downloadedSongs.count
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueUniversalCell()
            cell.show(cached: false, number: false, art: true, secondary: true, duration: false)
            cell.update(model: downloadedFolderAlbums[indexPath.row])
            return cell
        } else {
            let cell = tableView.dequeueUniversalCell()
            if let song = store.song(downloadedSong: downloadedSongs[indexPath.row]) {
                cell.update(song: song)
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let controller = DownloadedFolderAlbumViewController(folderAlbum: downloadedFolderAlbums[indexPath.row])
            pushViewControllerCustom(controller)
        } else if let song = store.playSong(position: indexPath.row, downloadedSongs: downloadedSongs), !song.isVideo {
            showPlayer()
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // TODO: implement this
        return nil
    }
}
