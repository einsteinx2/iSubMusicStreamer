//
//  DownloadsViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import Resolver

@objc final class DownloadsViewController: UIViewController {
    @Injected private var store: Store
    
    private let tableView = UITableView()
    
    // TODO: Separately track downloaded folders, artists, albums, and songs to show the appropriate table cells
    private var downloadedSongsCount = 0
    
    private func registerForNotifications() {
        // Set notification receiver for when queued songs finish downloading to reload the table
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadTable), name: ISMSNotification_StreamHandlerSongDownloaded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadTable), name: ISMSNotification_CacheQueueSongDownloaded)
        
        // Set notification receiver for when cached songs are deleted to reload the table
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadTable), name: ISMSNotification_CachedSongDeleted)
        
        // Set notification receiver for when network status changes to reload the table
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadTable), name:NSNotification.Name.reachabilityChanged.rawValue)
    }
    
    private func unregisterForNotifications() {
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_StreamHandlerSongDownloaded)
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_CacheQueueSongDownloaded)
        NotificationCenter.removeObserverOnMainThread(self, name: ISMSNotification_CachedSongDeleted)
        NotificationCenter.removeObserverOnMainThread(self, name: NSNotification.Name.reachabilityChanged.rawValue)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Colors.background
        title = "Downloads"
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = Colors.background
        tableView.rowHeight = Defines.rowHeight
        tableView.separatorStyle = .none
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.leading.trailing.top.bottom.equalToSuperview()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        registerForNotifications()
        reloadTable()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterForNotifications()
    }
    
    @objc private func reloadTable() {
        downloadedSongsCount = store.downloadedSongsCount()
        tableView.reloadData()
    }
}

extension DownloadsViewController: UITableViewDelegate, UITableViewDataSource {
    private enum RowType: Int {
        case folders = 0
        case artists = 1
        case albums = 2
        case songs = 3
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return downloadedSongsCount > 0 ? 4 : 0
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        cell.hideCacheIndicator = true
        cell.hideNumberLabel = true
        cell.hideCoverArt = true
        cell.hideSecondaryLabel = true
        cell.hideDurationLabel = true
        switch RowType(rawValue: indexPath.row) {
        case .folders: cell.update(primaryText: "Folders", secondaryText: nil)
        case .artists: cell.update(primaryText: "Artists", secondaryText: nil)
        case .albums:  cell.update(primaryText: "Albums", secondaryText: nil)
        case .songs:   cell.update(primaryText: "Songs", secondaryText: nil)
        default: break
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let controller: UIViewController?
        switch RowType(rawValue: indexPath.row) {
        case .folders: controller = DownloadedFolderArtistsViewController()
        case .artists: controller = DownloadedTagArtistsViewController()
        case .albums:  controller = DownloadedTagAlbumsViewController()
        case .songs:   controller = DownloadedSongsViewController()
        default: controller = nil
        }
        if let controller = controller {
            pushCustom(controller)
        }
    }

}
