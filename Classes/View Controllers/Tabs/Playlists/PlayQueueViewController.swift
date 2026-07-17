//
//  PlayQueueViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import CocoaLumberjackSwift
import Resolver

final class PlayQueueViewController: CustomUITableViewController {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
    @Injected private var jukebox: Jukebox
    @Injected private var playQueue: PlayQueue
    @Injected private var analytics: Analytics
    @Injected private var playbackCoordinator: PlaybackCoordinator
    
    private let saveEditHeader = SaveEditHeader(saveType: "playlist", countType: "song", pluralizeClearType: false, isLargeCount: false)
    private lazy var savePlaylistFlow = SavePlaylistFlow(viewController: self)
    private let backgroundColor: UIColor?
    
    init(backgroundColor: UIColor? = Colors.background) {
        self.backgroundColor = backgroundColor
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
        
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    private func registerForNotifications() {
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(selectRow), name: Notifications.bassInitialized)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(selectRow), name: Notifications.bassFreed)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(selectRow), name: Notifications.currentPlaylistIndexChanged)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(selectRow), name: Notifications.currentPlaylistShuffleToggled)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(jukeboxSongInfoUpdated), name: Notifications.jukeboxSongInfo)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(songsQueued), name: Notifications.currentPlaylistSongsQueued)
    }
    
    private func unregisterForNotifications() {
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.bassInitialized)
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.bassFreed)
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.currentPlaylistIndexChanged)
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.currentPlaylistShuffleToggled)
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.jukeboxSongInfo)
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.currentPlaylistSongsQueued)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = backgroundColor
        title = "Play Queue"
        setupDefaultTableView(tableView)
        tableView.allowsMultipleSelectionDuringEditing = true
        registerForNotifications()
        if isModal {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismiss(sender:)))
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The queue notifications are only observed while on screen (see
        // viewWillDisappear), so anything that changed the queue while this tab was
        // hidden — queueing from the Library, a library-context switch — would
        // otherwise leave a stale table
        tableView.reloadData()
        selectRow()
        addOrRemoveSaveEditHeader()
        analytics.log(event: isModal ? .playerPlayQueue : .playQueueTab)
        if settings.isJukeboxEnabled {
            jukebox.getInfo()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterForNotifications()
        if isEditing {
            setEditing(false, animated: true)
        }
    }
    
    private func addOrRemoveSaveEditHeader() {
        if playQueue.count > 0 {
            addSaveEditHeader()
        } else {
            removeSaveEditHeader()
        }
    }
    
    private func addSaveEditHeader() {
        guard saveEditHeader.superview == nil else { return }
        
        saveEditHeader.delegate = self
        saveEditHeader.count = playQueue.count
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
    
    @objc private func selectRow() {
        tableView.reloadData()
        let currentIndex = playQueue.currentIndex
        if currentIndex >= 0 && currentIndex < playQueue.count {
            tableView.selectRow(at: IndexPath(row: currentIndex, section: 0), animated: false, scrollPosition: .top)
        }
    }
    
    @objc private func jukeboxSongInfoUpdated() {
        saveEditHeader.count = playQueue.count
        selectRow()
        addOrRemoveSaveEditHeader()
    }
    
    @objc private func songsQueued() {
        saveEditHeader.count = playQueue.count
        tableView.reloadData()
        addOrRemoveSaveEditHeader()
    }
    
    @objc private func dismiss(sender: Any) {
        if let navigationController {
            navigationController.dismiss(animated: true, completion: nil)
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
        saveEditHeader.setEditing(editing, animated: animated)
        if isEditing {
            // Deselect all the rows
            for i in 0..<playQueue.count {
                tableView.deselectRow(at: IndexPath(row: i, section: 0), animated: false)
            }
        } else {
            selectRow()
        }
    }
    
    var selectedRows: [Int] {
        if let indexPathsForSelectedRows = tableView.indexPathsForSelectedRows {
            return indexPathsForSelectedRows.map { $0.row }
        }
        return []
    }
    
    var selectedRowsCount: Int {
        return tableView.indexPathsForSelectedRows?.count ?? 0
    }
    
    private func updateTableCellNumbers() {
        if let indexPathsForSelectedRows = tableView.indexPathsForSelectedRows {
            for indexPath in indexPathsForSelectedRows {
                if let cell = tableView.cellForRow(at: indexPath) as? UniversalTableViewCell {
                    cell.number = indexPath.row + 1
                }
            }
        }
    }
    
    override func tableCellModel(at indexPath: IndexPath) -> TableCellModel? {
        return playQueue.song(index: indexPath.row)
    }
}

extension PlayQueueViewController: SaveEditHeaderDelegate {
    func saveEditHeaderSaveDeleteAction(_ saveEditHeader: SaveEditHeader) {
        if saveEditHeader.isEditing {
            unregisterForNotifications()
            
            if selectedRowsCount == 0 {
                // Select all the rows
                for i in 0..<playQueue.count {
                    tableView.selectRow(at: IndexPath(row: i, section: 0), animated: false, scrollPosition: .none)
                }
                saveEditHeader.selectedCount = playQueue.count
            } else {
                // Delete action
                _ = playbackCoordinator.removeSongs(indexes: selectedRows)
                saveEditHeader.count = playQueue.count
                tableView.deleteRows(at: tableView.indexPathsForSelectedRows ?? [], with: .automatic)
                updateTableCellNumbers()
                setEditing(false, animated: true)
            }
            
            if !settings.isJukeboxEnabled {
                NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistOrderChanged)
            }
            
            registerForNotifications()
            addOrRemoveSaveEditHeader()
        } else {
            savePlaylistFlow.promptToSavePlayQueue()
        }
    }
    
    func saveEditHeaderEditAction(_ saveEditHeader: SaveEditHeader) {
        setEditing(!self.isEditing, animated: true)
    }
}

extension PlayQueueViewController: UITableViewConfiguration {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playQueue.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.number = indexPath.row + 1
        cell.show(downloaded: true, number: true, art: true, secondary: true, duration: true)
        cell.update(model: playQueue.song(index: indexPath.row))
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        _ = playbackCoordinator.moveSong(fromIndex: sourceIndexPath.row, toIndex: destinationIndexPath.row)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditing {
            saveEditHeader.selectedCount += 1
            return
        }
        
        if isModal {
            dismiss(sender: self)
            DispatchQueue.main.async(after: 0.5) {
                self.playbackCoordinator.play(position: indexPath.row)
            }
        } else {
            playbackCoordinator.play(position: indexPath.row)
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isEditing {
            saveEditHeader.selectedCount -= 1
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let model = playQueue.song(index: indexPath.row), !model.isVideo else { return nil }
        return SwipeAction.downloadQueueAndDeleteConfig(model: model) { [unowned self] in
            _ = playbackCoordinator.removeSongs(indexes: [indexPath.row])
            self.saveEditHeader.count = playQueue.count
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
            self.addOrRemoveSaveEditHeader()
        }
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let model = playQueue.song(index: indexPath.row), !model.isVideo else { return nil }
        return contextMenuDownloadAndQueueConfig(model: model)
    }
}
