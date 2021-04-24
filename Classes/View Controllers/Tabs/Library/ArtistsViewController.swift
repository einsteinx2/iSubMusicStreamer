//
//  ArtistsViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import SnapKit
import CocoaLumberjackSwift

// TODO: implement this - refactor the loadData method to handle serverId better
final class ArtistsViewController: UIViewController {
    @Injected private var store: Store
    @Injected private var settings: Settings
    @Injected private var analytics: Analytics
    
    var serverId: Int { Settings.shared().currentServerId }
    
    private let tableView = UITableView()
    private let dropdownMenu = DropdownMenu()
    private let searchBar = UISearchBar()
    private var searchOverlay: UIVisualEffectView?
    private let countLabel = UILabel()
    private let reloadTimeLabel = UILabel()
    
    private var isSearching = false
    private var isCountShowing = false
    
    private let dataModel: ArtistsViewModel
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Resize the section headers on rotation
        for section in 0..<dataModel.tableSections.count {
            if let sectionHeader = tableView.headerView(forSection: section) as? BlurredSectionHeader {
                sectionHeader.viewWillTransition(to: size, with: coordinator)
            }
        }
    }
        
    // MARK: Lifecycle
    
    init(dataModel: ArtistsViewModel) {
        self.dataModel = dataModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Colors.background
        title = dataModel.itemType.pluralized
        
        dataModel.delegate = self
        dataModel.reset()
        dropdownMenu.delegate = self
        
        setupDefaultTableView(tableView)
        tableView.register(BlurredSectionHeader.self, forHeaderFooterViewReuseIdentifier: BlurredSectionHeader.reuseId)
        tableView.refreshControl = RefreshControl(handler: { [unowned self] in
            loadData(serverId: serverId, mediaFolderId: settings.rootFoldersSelectedFolderId?.intValue ?? MediaFolder.allFoldersId)
        })
        
        if dataModel.isCached {
            addCount()
            dropdownMenu.selectedIndex = dataModel.mediaFolderIndex
        }
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(serverSwitched), name: Notifications.serverSwitched)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadAction), name: Notifications.serverCheckPassed)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !dataModel.isCached {
            loadData(serverId: serverId, mediaFolderId: settings.rootFoldersSelectedFolderId?.intValue ?? MediaFolder.allFoldersId)
        }
        analytics.log(event: .foldersTab)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dropdownMenu.close(animated: false)
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
        dataModel.delegate = nil
        dropdownMenu.delegate = nil
    }
    
    // MARK: Loading
    
    private func updateCount() {
        let count = isSearching ? dataModel.searchCount : dataModel.count
        countLabel.text = "\(count) \(dataModel.itemType.pluralize(amount: count))"
        if let reloadDate = dataModel.reloadDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let formattedTime = formatter.string(from: reloadDate)
            reloadTimeLabel.text = "last reload \(formattedTime)"
        } else {
            reloadTimeLabel.text = ""
        }
    }
    
    private func removeCount() {
        guard isCountShowing else { return }
        tableView.tableHeaderView = nil
        isCountShowing = false
    }
    
    private func addCount() {
        guard !isCountShowing else { return }
        isCountShowing = true
        
        // NOTE: Unfortunately the header container view must not use autolayout or the
        //       header resizing won't work, but all of it's subviews can use it at least.
        let headerView = UIView()
        headerView.frame = CGRect(x: 0, y: 0, width: 320, height: UIDevice.isSmall ? 154 : 158)
        headerView.autoresizingMask = .flexibleWidth
        headerView.backgroundColor = view.backgroundColor
        tableView.tableHeaderView = headerView
        
        countLabel.textColor = .label
        countLabel.textAlignment = .center
        countLabel.font = .boldSystemFont(ofSize: 32)
        headerView.addSubview(countLabel)
        countLabel.snp.makeConstraints { make in
            make.height.equalTo(30)
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(10)
        }

        reloadTimeLabel.textColor = .secondaryLabel
        reloadTimeLabel.textAlignment = .center
        reloadTimeLabel.font = .systemFont(ofSize: 11)
        headerView.addSubview(reloadTimeLabel)
        reloadTimeLabel.snp.makeConstraints { make in
            make.height.equalTo(14)
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(countLabel.snp.bottom).offset(5)
        }
        
        headerView.addSubview(dropdownMenu)
        dropdownMenu.snp.makeConstraints { make in
            make.width.lessThanOrEqualTo(300)
            make.centerX.equalToSuperview()
            make.leading.equalToSuperview().offset(50).priority(.high)
            make.trailing.equalToSuperview().offset(-50).priority(.high)
            make.top.equalTo(reloadTimeLabel.snp.bottom).offset(5)
        }
        
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.autocorrectionType = .no
        searchBar.placeholder = "Folder name"
        headerView.addSubview(searchBar)
        searchBar.snp.makeConstraints { make in
            make.height.equalTo(40)
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(dropdownMenu.snp.bottom).offset(5)
            make.bottom.equalToSuperview().offset(-5)
        }

        updateCount()

//        // Special handling for voice over users
//        if UIAccessibility.isVoiceOverRunning {
//            // Add a refresh button
//            let voiceOverRefresh = UIButton(type: .custom)
//            voiceOverRefresh.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
//            voiceOverRefresh.addTarget(self, action: #selector(reloadAction), for: .touchUpInside)
//            voiceOverRefresh.accessibilityLabel = "Reload Folders"
//            headerView.addSubview(voiceOverRefresh)
//
//            // Resize the two labels at the top so the refresh button can be pressed
//            countLabel.frame = CGRect(x: 50, y: 5, width: 220, height: 30)
//            reloadTimeLabel.frame = CGRect(x: 50, y: 36, width: 220, height: 12)
//        }
    }
    
    @objc private func reloadAction() {
        loadData(serverId: serverId, mediaFolderId: settings.rootFoldersSelectedFolderId?.intValue ?? MediaFolder.allFoldersId)
    }

    private func loadData(serverId: Int, mediaFolderId: Int) {
        HUD.show(closeHandler: cancelLoad)
        dataModel.serverId = serverId
        dataModel.mediaFolderId = mediaFolderId
        dataModel.startLoad()
    }
    
    @objc private func serverSwitched() {
        dataModel.reset()
        if !dataModel.isCached {
            tableView.reloadData()
            removeCount()
        }
        dropdownMenu.selectedIndex = 0
    }
}

extension ArtistsViewController: APILoaderDelegate {
    func cancelLoad() {
        HUD.hide()
        dataModel.cancelLoad()
        tableView.refreshControl?.endRefreshing()
    }
    
    func loadingFinished(loader: APILoader?) {
        HUD.hide()
        dropdownMenu.selectedIndex = dataModel.mediaFolderIndex
        dropdownMenu.updateItems()
        if isCountShowing {
            updateCount()
        } else {
            addCount()
        }
        
        tableView.reloadData()
        tableView.refreshControl?.endRefreshing()
    }
    
    func loadingFailed(loader: APILoader?, error: Error?) {
        HUD.hide()
        tableView.refreshControl?.endRefreshing()
        
        // Inform the user that the connection failed.
        // NOTE: Must call after a delay or the refresh control won't hide
        DispatchQueue.main.async(after: 0.3) {
            var message = "Unknown error, please try again."
            if let error = error as? SubsonicError, case .trialExpired = error {
                message = "\(error.localizedDescription)"
            } else if let error = error {
                message = "\(error)"
            }
            let alert = UIAlertController(title: "Subsonic Error", message: message, preferredStyle: .alert)
            alert.addOKAction()
            self.present(alert, animated: true, completion: nil)
        }
    }
}

extension ArtistsViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        beginSearching()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        dataModel.clearSearch()
        if searchText.count > 0 {
            hideSearchOverlay()
            dataModel.search(name: searchText)
        } else {
            createSearchOverlay()
        }
        tableView.reloadData()
        scrollTableViewToSearchBar(animated: false)
        updateCount()
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        // Dismiss the keyboard
        searchBar.resignFirstResponder()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        // Dismiss the keyboard
        searchBar.resignFirstResponder()
    }
    
    private func scrollTableViewToSearchBar(animated: Bool) {
        // Fixes issues with scrolling the content offset when there are a small number of cells
        tableView.setNeedsLayout()
        tableView.layoutIfNeeded()
        
        // Scroll to the offset
        let offsetY = searchBar.frame.origin.y - 5
        if animated {
            UIView.animate(withDuration: 0.15) {
                self.tableView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
            }
        } else {
            tableView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
        }
    }
    
    private func beginSearching() {
        guard !isSearching else { return }
        
        isSearching = true
        title = "Searching \(dataModel.itemType.pluralized)"
        dataModel.clearSearch()
        tableView.reloadData()
        dropdownMenu.close(animated: false)
        scrollTableViewToSearchBar(animated: true)
        if (searchBar.text?.count ?? 0) == 0 {
            createSearchOverlay()
        }
        
        // Add the done button
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(finishSearching))
    }
    
    @objc private func finishSearching() {
        guard isSearching else { return }
        
        isSearching = false
        title = dataModel.itemType.pluralized
        searchBar.text = ""
        searchBar.resignFirstResponder()
        hideSearchOverlay()
        navigationItem.leftBarButtonItem = nil
        dataModel.clearSearch()
        tableView.reloadData()
        updateCount()
    }
    
    private func createSearchOverlay() {
        guard searchOverlay == nil else { return }
        
        let effectStyle: UIBlurEffect.Style = traitCollection.userInterfaceStyle == .dark ? .systemUltraThinMaterialLight : .systemUltraThinMaterialDark
        let searchOverlay = UIVisualEffectView(effect: UIBlurEffect(style: effectStyle))
        self.searchOverlay = searchOverlay
        view.addSubview(searchOverlay)
        searchOverlay.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalToSuperview().offset(50)
        }
        
        let dismissButton = UIButton(type: .custom)
        dismissButton.addTarget(self, action: #selector(finishSearching), for: .touchUpInside)
        searchOverlay.contentView.addSubview(dismissButton)
        dismissButton.snp.makeConstraints { make in
            make.leading.trailing.top.bottom.equalToSuperview()
        }
        
        // Animate the search overlay on screen
        searchOverlay.alpha = 0
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut, animations: {
            searchOverlay.alpha = 1
        }, completion: nil)
    }
    
    private func hideSearchOverlay() {
        if let searchOverlay = searchOverlay {
            // Animate the search overlay off screen
            UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) {
                searchOverlay.alpha = 0
            } completion: { _ in
                searchOverlay.removeFromSuperview()
                self.searchOverlay = nil
            }
        }
    }
}

extension ArtistsViewController: UITableViewDelegate, UITableViewDataSource {
    private func artist(indexPath: IndexPath) -> Artist? {
        if isSearching {
            return dataModel.artistInSearch(indexPath: indexPath)
        } else {
            return dataModel.artist(indexPath: indexPath)
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if isSearching {
            return 1
        }
        return dataModel.tableSections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSearching {
            return dataModel.searchCount
        } else if section < dataModel.tableSections.count {
            return dataModel.tableSections[section].itemCount
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.hideCoverArt = !dataModel.showCoverArt
        cell.update(model: artist(indexPath: indexPath))
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if isSearching { return nil }
        if section >= dataModel.tableSections.count { return nil }
        
        let sectionHeader = tableView.dequeueReusableHeaderFooterView(withIdentifier: BlurredSectionHeader.reuseId) as! BlurredSectionHeader
        sectionHeader.text = dataModel.tableSections[section].name
        sectionHeader.updateFont()
        return sectionHeader
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if isSearching { return 0 }
        if section >= dataModel.tableSections.count { return 0 }
        
        let landscapeHeight: CGFloat = UIDevice.isSmall ? 20 : 24
        return UIApplication.orientation.isPortrait ? Defines.rowHeight - 5 : landscapeHeight
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        if isSearching { return nil }
        
        var titles = ["{search}"]
        for section in dataModel.tableSections {
            titles.append(section.name)
        }
        return titles
    }
    
    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        if isSearching { return -1 }
        
        if index == 0 {
            let yOffset: CGFloat = dataModel.mediaFolders.count > 1 ? dropdownMenu.frame.origin.y - 5 : searchBar.frame.origin.y - 5
            tableView.setContentOffset(CGPoint(x: 0, y: yOffset), animated: false)
            return -1
        }
        return index - 1
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let artist = artist(indexPath: indexPath) {
            if let artist = artist as? FolderArtist {
                pushViewControllerCustom(FolderAlbumViewController(folderArtist: artist))
            } else if let artist = artist as? TagArtist {
                pushViewControllerCustom(TagArtistViewController(tagArtist: artist))
            }
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return SwipeAction.downloadAndQueueConfig(model: artist(indexPath: indexPath))
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return contextMenuDownloadAndQueueConfig(model: artist(indexPath: indexPath))
    }
}

extension ArtistsViewController: DropdownMenuDelegate {
    func dropdownMenuNumberOfItems(_ dropdownMenu: DropdownMenu) -> Int {
        return dataModel.mediaFolders.count + 1
    }
    
    func dropdownMenu(_ dropdownMenu: DropdownMenu, titleForIndex index: Int) -> String {
        guard index >= 0 && index < dataModel.mediaFolders.count else { return "" }
        return dataModel.mediaFolders[index].name
    }
    
    func dropdownMenu(_ dropdownMenu: DropdownMenu, selectedItemAt index: Int) {
        guard index >= 0 && index < dataModel.mediaFolders.count else { return }
        
        // Save the default
        let mediaFolderId = dataModel.mediaFolders[index].id
        settings.rootFoldersSelectedFolderId = NSNumber(value: mediaFolderId)

        // Reload the data
        dataModel.mediaFolderId = mediaFolderId
        isSearching = false
        if dataModel.isCached {
            tableView.reloadData()
            updateCount()
        } else {
            loadData(serverId: serverId, mediaFolderId: mediaFolderId)
        }
    }

    func dropdownMenu(_ dropdownMenu: DropdownMenu, willToggleWithHeightChange heightChange: CGFloat, animated: Bool, animationDuration: Double) {
        func resizeHeader() {
            do {
                try ObjC.perform {
                    tableView.performBatchUpdates({
                        tableView.tableHeaderView?.frame.size.height += heightChange
                        tableView.tableHeaderView = tableView.tableHeaderView
                        tableView.tableHeaderView?.layoutIfNeeded()
                        
                        for section in 0..<dataModel.tableSections.count {
                            if let sectionHeader = tableView.headerView(forSection: section) {
                                sectionHeader.frame.origin.y += heightChange
                            }
                        }
                    })
                }
            } catch {
                // This is only a failsafe for certain cases where UITableView throws an exception due to the
                // number of sections changing, but doesn't cause any actual UI issues and only occurs rarely.
                DDLogError("[ArtistsViewController] exception thrown resizing table header: \(error)")
            }
        }
        
        if animated {
            UIView.animate(withDuration: animationDuration) {
                resizeHeader()
            }
        } else {
            resizeHeader()
        }
    }
}
