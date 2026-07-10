//
//  LocalPlaylistsViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import CocoaLumberjackSwift
import Resolver

final class LocalPlaylistsViewController: CustomUITableViewController {
    @Injected private var store: Store
    @Injected private var playQueue: PlayQueue
    @Injected private var analytics: Analytics
    
    private let saveEditHeader = SaveEditHeader(saveType: "playlist", countType: "song", pluralizeClearType: false, isLargeCount: false)
    private lazy var savePlaylistFlow = SavePlaylistFlow(viewController: self)

    private var localPlaylists = [LocalPlaylist]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Colors.background
        title = "Local Playlists"
        setupDefaultTableView(tableView)
        tableView.allowsMultipleSelectionDuringEditing = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
        analytics.log(event: .localPlaylistsTab)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setEditing(false, animated: false)
    }
    
    private func addSaveEditHeader() {
        guard saveEditHeader.superview == nil else { return }
        
        saveEditHeader.delegate = self
        saveEditHeader.count = localPlaylists.count
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
        setEditing(false, animated: false)
        removeSaveEditHeader()
        localPlaylists = store.localPlaylists()
        if localPlaylists.count > 0 {
            addSaveEditHeader()
        } else {
            removeSaveEditHeader()
        }
        tableView.reloadData()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
        saveEditHeader.setEditing(editing, animated: animated)
    }
    
    private func deleteLocalPlaylists(indexPaths: [IndexPath]) {
        let playlistIds = indexPaths.compactMap { $0.row < localPlaylists.count ? localPlaylists[$0.row].id : nil }
        guard playlistIds.count > 0 else { return }

        HUD.show(message: "Deleting")
        DispatchQueue.userInitiated.async {
            for playlistId in playlistIds {
                // Deletes the playlist and its localPlaylistSong rows
                self.store.delete(localPlaylistId: playlistId)
            }
            DispatchQueue.main.async {
                HUD.hide()
                self.reloadData()
            }
        }
    }
    
    func cancelLoad() {
        savePlaylistFlow.cancel()
        HUD.hide()
    }

    override func tableCellModel(at indexPath: IndexPath) -> TableCellModel? {
        guard indexPath.row < localPlaylists.count else { return nil }
        return localPlaylists[indexPath.row]
    }
}

extension LocalPlaylistsViewController: SaveEditHeaderDelegate {
    func saveEditHeaderEditAction(_ saveEditHeader: SaveEditHeader) {
        setEditing(!isEditing, animated: true)
    }
    
    func saveEditHeaderSaveDeleteAction(_ saveEditHeader: SaveEditHeader) {
        if saveEditHeader.isEditing {
            if let indexPathsForSelectedRows = tableView.indexPathsForSelectedRows, indexPathsForSelectedRows.count > 0 {
                deleteLocalPlaylists(indexPaths: indexPathsForSelectedRows)
            } else {
                // Nothing selected, so select all the rows (mirrors the Play Queue tab)
                for i in 0..<localPlaylists.count {
                    tableView.selectRow(at: IndexPath(row: i, section: 0), animated: false, scrollPosition: .none)
                }
                saveEditHeader.selectedCount = localPlaylists.count
            }
        } else {
            // Save the current play queue as a new playlist, matching the Play Queue tab
            savePlaylistFlow.promptToSavePlayQueue()
        }
    }
}

extension LocalPlaylistsViewController: UITableViewConfiguration {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return localPlaylists.count
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.show(downloaded: false, number: false, art: false, secondary: true, duration: false)
        cell.update(model: localPlaylists[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditing {
            saveEditHeader.selectedCount += 1
            return
        }
        
        pushViewControllerCustom(LocalPlaylistViewController(localPlaylist: localPlaylists[indexPath.row]))
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isEditing {
            saveEditHeader.selectedCount -= 1
            return
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return SwipeAction.downloadQueueAndDeleteConfig(model: localPlaylists[indexPath.row]) {
            self.deleteLocalPlaylists(indexPaths: [indexPath])
        }
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return contextMenuDownloadAndQueueConfig(model: localPlaylists[indexPath.row])
    }
}
