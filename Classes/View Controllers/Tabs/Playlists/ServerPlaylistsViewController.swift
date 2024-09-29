//
//  ServerPlaylistsViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import CocoaLumberjackSwift
import Resolver

final class ServerPlaylistsViewController: CustomUITableViewController {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
    @Injected private var playQueue: PlayQueue
    @Injected private var analytics: Analytics
    
    var serverId: Int { (Resolver.resolve() as SavedSettings).currentServerId }
    
    private let saveEditHeader = SaveEditHeader(saveType: "playlist", countType: "playlist", pluralizeClearType: false, isLargeCount: true)
    
    private var serverPlaylistsLoader: ServerPlaylistsLoader?
    private var serverPlaylists = [ServerPlaylist]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Colors.background
        title = "Server Playlists"
        
        tableView.allowsMultipleSelectionDuringEditing = true
        setupDefaultTableView(tableView)
    }
    
    deinit {
        cancelLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
        if serverPlaylists.count > 0 {
            addSaveEditHeader()
        } else {
            loadServerPlaylists()
        }
        analytics.log(event: .serverPlaylistsTab)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.setEditing(false, animated: false)
    }
    
    private func addSaveEditHeader() {
        guard saveEditHeader.superview == nil else { return }
        
        saveEditHeader.delegate = self
        saveEditHeader.count = serverPlaylists.count
        view.addSubview(saveEditHeader)
        saveEditHeader.snp.makeConstraints { make in
            make.height.equalTo(50)
            make.leading.trailing.top.equalToSuperview()
        }
        
        tableView.snp.updateConstraints { make in
            make.top.equalToSuperview().offset(50)
        }
        tableView.setNeedsUpdateConstraints()
    }
    
    private func removeSaveEditHeader() {
        guard saveEditHeader.superview != nil else { return }
        
        saveEditHeader.removeFromSuperview()
        
        tableView.snp.updateConstraints { make in
            make.top.equalToSuperview().offset(0)
        }
        tableView.setNeedsUpdateConstraints()
    }
    
    private func reloadData() {
        tableView.refreshControl = nil
        setEditing(false, animated: false)
        removeSaveEditHeader()
        serverPlaylists = store.serverPlaylists(serverId: serverId)
        tableView.reloadData()
        tableView.refreshControl = RefreshControl { [unowned self] in
            loadServerPlaylists()
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
        saveEditHeader.setEditing(editing, animated: animated)
    }
    
    private func deleteServerPlaylists(indexPaths: [IndexPath]) {
        // TODO: implement this
    //    self.tableView.scrollEnabled = NO;
    //    [viewObjectsS showAlbumLoadingScreen:self.view sender:self];
    //
    //    for (NSNumber *index in rowIndexes) {
    //        NSString *playlistId = [[self.serverPlaylistsDataModel.serverPlaylists objectAtIndexSafe:[index intValue]] playlistId];
    //        NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"deletePlaylist" parameters:@{@"id": n2N(playlistId)}];
    //        NSURLSessionDataTask *dataTask = [self.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    //            if (error) {
    //                // TODO: Handle error
    //            }
    //            [EX2Dispatch runInMainThreadAsync:^{
    //                [HUD hide];
    //                [self reloadData];
    //            }];
    //        }];
    //        [dataTask resume];
    //    }
    }
    
    private func loadServerPlaylists() {
        cancelLoad()
        HUD.show(closeHandler: cancelLoad)
        serverPlaylistsLoader = ServerPlaylistsLoader(serverId: serverId)
        serverPlaylistsLoader?.callback = { [unowned self] _, success, error in
            HUD.hide()
            tableView.refreshControl?.endRefreshing()
            if success {
                reloadData()
            } else {
                // TODO: Show error message
            }
        }
        serverPlaylistsLoader?.startLoad()
    }
    
    @objc func cancelLoad() {
        HUD.hide()
        serverPlaylistsLoader?.cancelLoad()
        serverPlaylistsLoader?.callback = nil
        serverPlaylistsLoader = nil
    }
    
    override func tableCellModel(at indexPath: IndexPath) -> TableCellModel? {
        guard indexPath.row < serverPlaylists.count else { return nil }
        return serverPlaylists[indexPath.row]
    }
}

extension ServerPlaylistsViewController: SaveEditHeaderDelegate {
    func saveEditHeaderEditAction(_ saveEditHeader: SaveEditHeader) {
        setEditing(!isEditing, animated: true)
    }
    
    func saveEditHeaderSaveDeleteAction(_ saveEditHeader: SaveEditHeader) {
        if let indexPathsForSelectedRows = tableView.indexPathsForSelectedRows {
            deleteServerPlaylists(indexPaths: indexPathsForSelectedRows)
        }
    }
}

extension ServerPlaylistsViewController: UITableViewConfiguration {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return serverPlaylists.count
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.show(downloaded: false, number: false, art: true, secondary: true, duration: false)
        cell.update(model: serverPlaylists[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditing {
            saveEditHeader.selectedCount += 1
            return
        }
        pushViewControllerCustom(ServerPlaylistViewController(serverPlaylist: serverPlaylists[indexPath.row]))
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isEditing {
            saveEditHeader.selectedCount -= 1
            return
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return SwipeAction.downloadQueueAndDeleteConfig(model: serverPlaylists[indexPath.row]) {
            self.deleteServerPlaylists(indexPaths: [indexPath])
        }
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return contextMenuDownloadAndQueueConfig(model: serverPlaylists[indexPath.row])
    }
}
