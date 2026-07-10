//
//  LocalPlaylistViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import Resolver

final class LocalPlaylistViewController: CustomUITableViewController {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
    
    private let localPlaylist: LocalPlaylist
    private lazy var savePlaylistFlow = SavePlaylistFlow(viewController: self)

    init(localPlaylist: LocalPlaylist) {
        self.localPlaylist = localPlaylist
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = localPlaylist.name
        setupDefaultTableView(tableView)
        
        if !settings.isOfflineMode {
            let headerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 50))
            
            let saveButton = UIButton(type: .custom)
            saveButton.frame = CGRect(x: 0, y: 0, width: 320, height: 50)
            saveButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            saveButton.addTarget(self, action: #selector(uploadPlaylist), for: .touchUpInside)
            saveButton.setTitle("Save to Server", for: .normal)
            saveButton.setTitleColor(.systemBlue, for: .normal)
            saveButton.titleLabel?.textAlignment = .center
            saveButton.titleLabel?.font = .boldSystemFont(ofSize: 24)
            headerView.addSubview(saveButton)
            
            tableView.tableHeaderView = headerView
        }
    }

    @objc private func uploadPlaylist() {
        let serverId = settings.currentServerId
        let songIds = store.songIds(localPlaylistId: localPlaylist.id, serverId: serverId)
        savePlaylistFlow.upload(name: localPlaylist.name, songIds: songIds, serverId: serverId)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        savePlaylistFlow.cancel()
    }
    
    override func tableCellModel(at indexPath: IndexPath) -> TableCellModel? {
        return song(indexPath: indexPath)
    }
}

extension LocalPlaylistViewController: UITableViewConfiguration {
    private func song(indexPath: IndexPath) -> Song? {
        return store.song(localPlaylistId: localPlaylist.id, position: indexPath.row)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return localPlaylist.songCount
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.show(downloaded: true, number: true, art: true, secondary: true, duration: true)
        cell.number = indexPath.row + 1
        cell.update(model: song(indexPath: indexPath))
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        HUD.show()
        DispatchQueue.userInitiated.async {
            // TODO: implement this
            
            HUD.hide()
//            if !song.isVideo {
//                NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
//            }
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let model = song(indexPath: indexPath) else { return nil }
        return SwipeAction.downloadAndQueueConfig(model: model)
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let model = song(indexPath: indexPath) else { return nil }
        return contextMenuDownloadAndQueueConfig(model: model)
    }
}
