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
    
    private var loaderTask: Task<Void, Never>?
    private var deleteTask: Task<Void, Never>?
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
        if serverPlaylists.count == 0 {
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
        serverPlaylists = store.serverPlaylists(serverId: serverId)
        if serverPlaylists.count > 0 {
            addSaveEditHeader()
            saveEditHeader.count = serverPlaylists.count
        } else {
            removeSaveEditHeader()
        }
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
        let playlistsToDelete = indexPaths.compactMap { $0.row < serverPlaylists.count ? serverPlaylists[$0.row] : nil }
        guard playlistsToDelete.count > 0 else { return }

        deleteTask?.cancel()
        deleteTask = Task {
            defer {
                HUD.hide()
                reloadData()
            }
            do {
                HUD.show(message: "Deleting", closeHandler: cancelLoad)
                for serverPlaylist in playlistsToDelete {
                    try await AsyncServerPlaylistDeleteLoader(serverPlaylist: serverPlaylist).load()
                    // Only remove the local copy once the server confirms the deletion
                    _ = store.delete(serverPlaylist: serverPlaylist)
                }
            } catch {
                if settings.isPopupsEnabled && !error.isCanceled {
                    let message = "There was an error deleting the playlist.\n\nError: \(error)"
                    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                    alert.addOKAction()
                    present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    private func loadServerPlaylists() {
        loaderTask?.cancel()
        loaderTask = Task {
            do {
                HUD.show(closeHandler: cancelLoad)
                defer {
                    HUD.hide()
                    tableView.refreshControl?.endRefreshing()
                }
                
                serverPlaylists = try await AsyncServerPlaylistsLoader(serverId: serverId).load()
                reloadData()
            } catch {
                // TODO: Show error message
            }
        }
    }
    
    func cancelLoad() {
        HUD.hide()
        loaderTask?.cancel()
        loaderTask = nil
        deleteTask?.cancel()
        deleteTask = nil
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
        guard saveEditHeader.isEditing else { return }

        if let indexPathsForSelectedRows = tableView.indexPathsForSelectedRows, indexPathsForSelectedRows.count > 0 {
            deleteServerPlaylists(indexPaths: indexPathsForSelectedRows)
        } else {
            // Nothing selected, so select all the rows (mirrors the Play Queue tab)
            for i in 0..<serverPlaylists.count {
                tableView.selectRow(at: IndexPath(row: i, section: 0), animated: false, scrollPosition: .none)
            }
            saveEditHeader.selectedCount = serverPlaylists.count
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
