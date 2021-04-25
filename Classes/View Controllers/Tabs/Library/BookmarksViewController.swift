//
//  BookmarksViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 2/2/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import CocoaLumberjackSwift
import Resolver

final class BookmarksViewController: CustomUITableViewController {
    @Injected private var store: Store
    @Injected private var analytics: Analytics
    @Injected private var settings: Settings
    
    private let saveEditHeader = SaveEditHeader(saveType: "bookmark", countType: "bookmark", pluralizeClearType: false, isLargeCount: false)
    
    private var bookmarks = [Bookmark]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Colors.background
        title = "Bookmarks"
        setupDefaultTableView(tableView)
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.rowHeight = Defines.tallRowHeight
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
        analytics.log(event: .bookmarksTab)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setEditing(false, animated: false)
    }
    
    private func addSaveEditHeader() {
        guard saveEditHeader.superview == nil else { return }
        
        saveEditHeader.delegate = self
        saveEditHeader.count = bookmarks.count
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
        bookmarks = store.bookmarks()
        if bookmarks.count > 0 {
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
    
    override func tableCellModel(at indexPath: IndexPath) -> TableCellModel? {
        guard indexPath.row < bookmarks.count else { return nil }
        return store.song(bookmark: bookmarks[indexPath.row])
    }
}

extension BookmarksViewController: SaveEditHeaderDelegate {
    func saveEditHeaderEditAction(_ saveEditHeader: SaveEditHeader) {
        setEditing(!isEditing, animated: true)
    }
    
    // TODO: implement this
    func saveEditHeaderSaveDeleteAction(_ saveEditHeader: SaveEditHeader) {
//        if saveEditHeader.isEditing {
//            HUD.show(message: "Deleting")
//            DispatchQueue.userInitiated.async {
//                defer { HUD.hide() }
//                if let indexPathsForSelectedRows = self.tableView.indexPathsForSelectedRows {
//                    self.deleteLocalPlaylists(indexPaths: indexPathsForSelectedRows)
//                }
//            }
//        }
    }
}

extension BookmarksViewController: UITableViewConfiguration {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bookmarks.count
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.show(downloaded: true, number: true, art: true, secondary: true, duration: true, header: true)
        let bookmark = bookmarks[indexPath.row]
        if let song = store.song(bookmark: bookmark), let playlist = store.localPlaylist(bookmark: bookmark) {
            cell.headerText = "\(playlist.name) - \(formatTime(seconds: bookmark.offsetInSeconds))"
            cell.update(model: song)
        }
        handleOfflineMode(cell: cell, at: indexPath)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditing {
            saveEditHeader.selectedCount += 1
            return
        }
        
        if let song = store.playSong(bookmark: bookmarks[indexPath.row]), !song.isVideo {
            NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isEditing {
            saveEditHeader.selectedCount -= 1
            return
        }
    }
    
    // TODO: implement this
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let bookmark = bookmarks[indexPath.row]
        return SwipeAction.downloadQueueAndDeleteConfig(downloadHandler: {
            guard let song = self.store.song(bookmark: bookmark) else { return }
            song.download()
        }, queueHandler: {
            guard let song = self.store.song(bookmark: bookmark) else { return }
            song.queue()
        }, deleteHandler: {
            if self.store.delete(bookmark: bookmark) {
                self.bookmarks.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        })
    }
}
