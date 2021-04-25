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
    private enum SectionType: Int, CaseIterable {
        case albums = 0, songs
    }
    
    @Injected private var store: Store
    @Injected private var settings: Settings
    @Injected private var downloadsManager: DownloadsManager
    @Injected private var downloadQueue: DownloadQueue
    
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
        super.init(nibName: nil, bundle: nil)
    }
    
    init(folderAlbum: DownloadedFolderAlbum) {
        self.downloadedFolderArtist = nil
        self.downloadedFolderAlbum = folderAlbum
        self.serverId = folderAlbum.serverId
        self.level = folderAlbum.level + 1
        self.parentPathComponent = folderAlbum.name
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
    
    override func deleteItems(indexPaths: [IndexPath]) {
        HUD.show()
        DispatchQueue.userInitiated.async {
            defer { HUD.hide() }
            for indexPath in indexPaths {
                if indexPath.section == SectionType.albums.rawValue {
                    _ = self.store.deleteDownloadedSongs(downloadedFolderAlbum: self.downloadedFolderAlbums[indexPath.row])
                } else if indexPath.section == SectionType.songs.rawValue {
                    _ = self.store.delete(downloadedSong: self.downloadedSongs[indexPath.row])
                }
            }
            self.downloadsManager.findCacheSize()
            NotificationCenter.postOnMainThread(name: Notifications.downloadedSongDeleted)
            if (!self.downloadQueue.isDownloading) {
                self.downloadQueue.start()
            }
        }
    }
    
    override func tableCellModel(at indexPath: IndexPath) -> TableCellModel? {
        if indexPath.section == SectionType.albums.rawValue {
            guard indexPath.row < downloadedFolderAlbums.count else { return nil }
            return downloadedFolderAlbums[indexPath.row]
        } else {
            guard indexPath.row < downloadedSongs.count else { return nil }
            return store.song(downloadedSong: downloadedSongs[indexPath.row])
        }
    }
}

extension DownloadedFolderAlbumViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return SectionType.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == SectionType.albums.rawValue ? downloadedFolderAlbums.count : downloadedSongs.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == SectionType.albums.rawValue {
            let cell = tableView.dequeueUniversalCell()
            cell.show(downloaded: false, number: false, art: true, secondary: true, duration: false)
            cell.update(model: downloadedFolderAlbums[indexPath.row])
            return cell
        } else {
            let cell = tableView.dequeueUniversalCell()
            if let song = store.song(downloadedSong: downloadedSongs[indexPath.row]) {
                cell.update(song: song, downloaded: false)
            }
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == SectionType.albums.rawValue {
            let controller = DownloadedFolderAlbumViewController(folderAlbum: downloadedFolderAlbums[indexPath.row])
            pushViewControllerCustom(controller)
        } else if let song = store.playSong(position: indexPath.row, downloadedSongs: downloadedSongs), !song.isVideo {
            NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        SwipeAction.downloadQueueAndDeleteConfig(downloadHandler: nil, queueHandler: {
            HUD.show()
            DispatchQueue.userInitiated.async {
                defer { HUD.hide() }
                if indexPath.section == SectionType.albums.rawValue {
                    self.downloadedFolderAlbums[indexPath.row].queue()
                } else if indexPath.section == SectionType.songs.rawValue {
                    self.store.song(downloadedSong: self.downloadedSongs[indexPath.row])?.queue()
                }
            }
        }, deleteHandler: {
            self.deleteItems(indexPaths: [indexPath])
        })
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        if indexPath.section == SectionType.albums.rawValue {
            return contextMenuDownloadAndQueueConfig(model: downloadedFolderAlbums[indexPath.row])
        } else {
            let song = store.song(downloadedSong: downloadedSongs[indexPath.row])
            return contextMenuDownloadAndQueueConfig(model: song)
        }
    }
}
