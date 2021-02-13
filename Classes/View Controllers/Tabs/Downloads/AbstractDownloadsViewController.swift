//
//  AbstractDownloadsViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/20/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit

class AbstractDownloadsViewController: UIViewController {
    let saveEditHeader = SaveEditHeader()
    let tableView = UITableView()
    
    var selectedRowsCount: Int { tableView.indexPathsForSelectedRows?.count ?? 0 }
    var itemCount: Int { fatalError("Must override in subclass") }
    
    func registerForNotifications() {
        // Set notification receiver for when queued songs finish downloading to reload the table
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadTable), name: Notifications.streamHandlerSongDownloaded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadTable), name: Notifications.cacheQueueSongDownloaded)
        
        // Set notification receiver for when cached songs are deleted to reload the table
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadTable), name: Notifications.cachedSongDeleted)
        
        // Set notification receiver for when network status changes to reload the table
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadTable), name:NSNotification.Name.reachabilityChanged)
    }
    
    func unregisterForNotifications() {
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.streamHandlerSongDownloaded)
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.cacheQueueSongDownloaded)
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.cachedSongDeleted)
        NotificationCenter.removeObserverOnMainThread(self, name: NSNotification.Name.reachabilityChanged)
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Colors.background
        setupDefaultTableView(tableView)
        tableView.allowsMultipleSelectionDuringEditing = true
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
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
        saveEditHeader.setEditing(editing, animated: animated)
    }
    
    @objc func reloadTable() {
        tableView.reloadData()
    }
    
    func deleteItems(indexPaths: [IndexPath]) {
        fatalError("Must override in subclass")
    }
    
    func addOrRemoveSaveEditHeader() {
        if itemCount > 0 {
            addSaveEditHeader()
        } else {
            removeSaveEditHeader()
        }
    }
    
    func addSaveEditHeader() {
        guard saveEditHeader.superview == nil else { return }
        
        saveEditHeader.delegate = self
        saveEditHeader.count = itemCount
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
    
    func removeSaveEditHeader() {
        guard saveEditHeader.superview != nil else { return }
        saveEditHeader.removeFromSuperview()
        tableView.snp.updateConstraints { make in
            make.top.equalToSuperview().offset(0)
        }
        tableView.setNeedsUpdateConstraints()
    }
}

extension AbstractDownloadsViewController: SaveEditHeaderDelegate {
    func saveEditHeaderEditAction(_ saveEditHeader: SaveEditHeader) {
        setEditing(!isEditing, animated: true)
    }
    
    func saveEditHeaderSaveDeleteAction(_ saveEditHeader: SaveEditHeader) {
        if saveEditHeader.isEditing {
            if selectedRowsCount == 0 {
                // Select all the rows
                for i in 0..<itemCount {
                    tableView.selectRow(at: IndexPath(row: i, section: 0), animated: false, scrollPosition: .none)
                }
                saveEditHeader.selectedCount = itemCount
            } else {
                deleteItems(indexPaths: tableView.indexPathsForSelectedRows ?? [])
            }
        }
    }
}

extension AbstractDownloadsViewController: UITableViewConfiguration {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return itemCount
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        fatalError("Must override in subclass")
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditing {
            saveEditHeader.selectedCount += 1
            return
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isEditing {
            saveEditHeader.selectedCount -= 1
            return
        }
    }
}
