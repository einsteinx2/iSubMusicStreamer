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

@objc final class ArtistsViewController: UIViewController {
    @Injected private var store: Store
    @Injected private var settings: Settings
    
    private let tableView = UITableView()
    private lazy var dropdown = FolderDropdownControl(frame: CGRect(x: 50, y: 61, width: 220, height: 40))
    private let searchBar = UISearchBar()
    private var searchOverlay: UIVisualEffectView?
    private let countLabel = UILabel()
    private let reloadTimeLabel = UILabel()
    
    private var isSearching = false
    private var isCountShowing = false
    
    private let dataModel: ArtistsViewModel
        
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
        title = "Folders"
        
        dataModel.delegate = self
        dataModel.reset()
        
        setupDefaultTableView(tableView)
        tableView.register(BlurredSectionHeader.self, forHeaderFooterViewReuseIdentifier: BlurredSectionHeader.reuseId)
        tableView.refreshControl = RefreshControl(handler: { [unowned self] in
            loadData(mediaFolderId: settings.currentServerId)
        })
        
        if dataModel.isCached {
            addCount()
            tableView.setContentOffset(CGPoint.zero, animated: false)
        }
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(serverSwitched), name: ISMSNotification_ServerSwitched)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(updateFolders), name: ISMSNotification_ServerCheckPassed)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(addURLRefBackButton), name: UIApplication.didBecomeActiveNotification.rawValue)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addURLRefBackButton()
        addShowPlayerButton()
        if !dataModel.isCached {
            loadData(mediaFolderId: settings.rootFoldersSelectedFolderId?.intValue ?? 0)
        }
        Flurry.logEvent("FoldersTab")
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
        dataModel.delegate = nil
        dropdown.delegate = nil
    }
    
    // MARK: Loading
    
    private func updateCount() {
        let count = dataModel.count
        countLabel.text = "\(count) \("Folder".pluralize(amount: count))"
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
        tableView.tableHeaderView = nil
        isCountShowing = false
    }
    
    private func addCount() {
        isCountShowing = true
        
        let headerView = UIView()
        headerView.frame = CGRect(x: 0, y: 0, width: 320, height: 157)
        headerView.autoresizingMask = .flexibleWidth
        headerView.backgroundColor = view.backgroundColor

        countLabel.frame = CGRect(x: 0, y: 9, width: 320, height: 30)
        countLabel.autoresizingMask = .flexibleWidth
        countLabel.textColor = .label
        countLabel.textAlignment = .center
        countLabel.font = .boldSystemFont(ofSize: 32)
        headerView.addSubview(countLabel)
        
        reloadTimeLabel.frame = CGRect(x: 0, y: 40, width: 320, height: 14)
        reloadTimeLabel.autoresizingMask = .flexibleWidth
        reloadTimeLabel.textColor = .secondaryLabel
        reloadTimeLabel.textAlignment = .center
        reloadTimeLabel.font = .systemFont(ofSize: 11)
        headerView.addSubview(reloadTimeLabel)
        
        dropdown = FolderDropdownControl(frame: CGRect(x: 50, y: 61, width: 220, height: 40))
        dropdown.frame = CGRect(x: 50, y: 61, width: 220, height: 40)
        dropdown.delegate = self
        dropdown.selectFolder(withId: dataModel.mediaFolderId)
        headerView.addSubview(dropdown)
        // TODO: Why is this hack needed in the Swift port but not in the original Obj-C version??
        DispatchQueue.main.async(after: 0.1) {
            self.dropdown.frame = CGRect(x: 50, y: 61, width: self.view.frame.width - 100, height: 40)
            print(self.dropdown.frame)
        }


        searchBar.frame = CGRect(x: 0, y: 111, width: 320, height: 40)
        searchBar.autoresizingMask = .flexibleWidth
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.autocorrectionType = .no
        searchBar.placeholder = "Folder name"
        headerView.addSubview(searchBar)

        updateCount()
        
        // Special handling for voice over users
        if UIAccessibility.isVoiceOverRunning {
            // Add a refresh button
            let voiceOverRefresh = UIButton(type: .custom)
            voiceOverRefresh.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
            voiceOverRefresh.addTarget(self, action: #selector(reloadAction), for: .touchUpInside)
            voiceOverRefresh.accessibilityLabel = "Reload Folders"
            headerView.addSubview(voiceOverRefresh)

            // Resize the two labels at the top so the refresh button can be pressed
            countLabel.frame = CGRect(x: 50, y: 5, width: 220, height: 30)
            reloadTimeLabel.frame = CGRect(x: 50, y: 36, width: 220, height: 12)
        }
        
        tableView.tableHeaderView = headerView
    }
    
    @objc private func reloadAction() {
        loadData(mediaFolderId: settings.rootFoldersSelectedFolderId?.intValue ?? 0)
    }

    private func loadData(mediaFolderId: Int) {
        dropdown.updateFolders()
        HUD.show(closeHandler: cancelLoad)
        dataModel.mediaFolderId = mediaFolderId
        dataModel.startLoad()
    }
}

extension ArtistsViewController: APILoaderDelegate {
    func cancelLoad() {
        dataModel.cancelLoad()
        tableView.refreshControl?.endRefreshing()
        HUD.hide()
    }
    
    func loadingFinished(loader: APILoader?) {
        if isCountShowing {
            updateCount()
        } else {
            addCount()
        }
        
        tableView.reloadData()
        HUD.hide()
        tableView.refreshControl?.endRefreshing()
    }
    
    func loadingFailed(loader: APILoader?, error: NSError?) {
        HUD.hide()
        tableView.refreshControl?.endRefreshing()
        
        // Inform the user that the connection failed.
        // NOTE: Must call after a delay or the refresh control won't hide
        DispatchQueue.main.async(after: 0.3) {
            let alert = UIAlertController(title: "Subsonic Error", message: error?.localizedDescription ?? "Unknown error", preferredStyle: .alert)
            alert.addCancelAction(title: "OK")
            self.present(alert, animated: true, completion: nil)
        }
    }
}

extension ArtistsViewController: FolderDropdownDelegate {
    func folderDropdownMoveViewsY(_ y: Float) {
        tableView.performBatchUpdates({
            tableView.tableHeaderView?.frame.size.height += CGFloat(y)
            searchBar.frame.origin.y += CGFloat(y)
            tableView.tableHeaderView = tableView.tableHeaderView
            
            let indexPathsForVisibleRows = tableView.indexPathsForVisibleRows ?? []
            let visibleSections = Set<Int>(indexPathsForVisibleRows.map({ $0.section }))
            for section in visibleSections {
                if let sectionHeader = tableView.headerView(forSection: section) {
                    sectionHeader.frame.origin.y += CGFloat(y)
                }
            }
        }, completion: nil)
    }
    
    func folderDropdownSelectFolder(_ mediaFolderId: Int) {
        // Save the default
        settings.rootFoldersSelectedFolderId = NSNumber(value: mediaFolderId)
        
        // Reload the data
        dataModel.mediaFolderId = mediaFolderId
        isSearching = false
        if dataModel.isCached {
            tableView.reloadData()
            updateCount()
        } else {
            loadData(mediaFolderId: mediaFolderId)
        }
    }
    
    func folderDropdownViewsFinishedMoving() {
        
    }
    
    @objc private func serverSwitched() {
        dataModel.reset()
        if !dataModel.isCached {
            tableView.reloadData()
            removeCount()
        }
        folderDropdownSelectFolder(MediaFolder.allFoldersId)
    }
    
    @objc private func updateFolders() {
        dropdown.updateFolders()
    }
}

extension ArtistsViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        guard !isSearching else { return }
        
        isSearching = true
        dataModel.clearSearch()
        
        dropdown.closeDropdownFast()
        tableView.setContentOffset(CGPoint(x: 0, y: 104), animated: true)
        
        if (searchBar.text?.count ?? 0) == 0 {
            createSearchOverlay()
        }
        
        // Add the done button
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(searchBarSearchButtonClicked(_:)))
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        dataModel.clearSearch()
        if searchText.count > 0 {
            hideSearchOverlay()
            dataModel.search(name: searchText)
//            tableView.setContentOffset(CGPoint(x: 0, y: 45), animated: false)
        } else {
            createSearchOverlay()
//            tableView.setContentOffset(CGPoint(x: 0, y: 104), animated: false)
//            tableView.setContentOffset(CGPoint(x: 0, y: 45), animated: false)
        }
        tableView.reloadData()
        tableView.setContentOffset(CGPoint(x: 0, y: 45), animated: false)
    }
    
    @objc func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        updateCount()
        
        self.searchBar.text = ""
        self.searchBar.resignFirstResponder()
        hideSearchOverlay()
        isSearching = false
        
        navigationItem.leftBarButtonItem = nil
        dataModel.clearSearch()
        tableView.reloadData()
        tableView.setContentOffset(CGPoint(x: 0, y: 104), animated: true)
    }
    
    private func createSearchOverlay() {
        let effectStyle: UIBlurEffect.Style = traitCollection.userInterfaceStyle == .dark ? .systemUltraThinMaterialLight : .systemUltraThinMaterialDark
        let searchOverlay = UIVisualEffectView(effect: UIBlurEffect(style: effectStyle))
        self.searchOverlay = searchOverlay
        view.addSubview(searchOverlay)
        searchOverlay.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalToSuperview().offset(50)
        }
        
        let dismissButton = UIButton(type: .custom)
        dismissButton.addTarget(self, action: #selector(searchBarSearchButtonClicked(_:)), for: .touchUpInside)
        searchOverlay.contentView.addSubview(dismissButton)
        dismissButton.snp.makeConstraints { make in
            make.leading.trailing.top.bottom.equalToSuperview()
        }
        
        // Animate the search overlay on screen
        searchOverlay.alpha = 0
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            searchOverlay.alpha = 1
        }, completion: nil)
    }
    
    private func hideSearchOverlay() {
        if let searchOverlay = searchOverlay {
            // Animate the search overlay off screen
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
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
        if isSearching && (dataModel.searchCount > 0 || (searchBar.text?.count ?? 0) > 0) {
            return dataModel.artistInSearch(indexPath: indexPath)
        } else {
            return dataModel.artist(indexPath: indexPath)
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if isSearching && (dataModel.searchCount > 0 || (searchBar.text?.count ?? 0) > 0) {
            return 1
        }
        return dataModel.tableSections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSearching && (dataModel.searchCount > 0 || (searchBar.text?.count ?? 0) > 0) {
            return dataModel.searchCount
        } else if section < dataModel.tableSections.count {
            return dataModel.tableSections[section].itemCount
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.update(model: artist(indexPath: indexPath))
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if isSearching && (dataModel.searchCount > 0 || (searchBar.text?.count ?? 0) > 0) { return nil }
        if section >= dataModel.tableSections.count { return nil }
        
        let sectionHeader = tableView.dequeueReusableHeaderFooterView(withIdentifier: BlurredSectionHeader.reuseId) as! BlurredSectionHeader
        sectionHeader.text = dataModel.tableSections[section].name
        return sectionHeader
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if isSearching && (dataModel.searchCount > 0 || (searchBar.text?.count ?? 0) > 0) { return 0 }
        if section >= dataModel.tableSections.count { return 0 }
        
        return Defines.rowHeight - 5
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        if isSearching && (dataModel.searchCount > 0 || (searchBar.text?.count ?? 0) > 0) { return nil }
        
        var titles = ["{search}"]
        for section in dataModel.tableSections {
            titles.append(section.name)
        }
        return titles
    }
    
    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        if isSearching && (dataModel.searchCount > 0 || (searchBar.text?.count ?? 0) > 0) { return -1 }
        
        if index == 0 {
            let yOffset: CGFloat = dropdown.hasMultipleMediaFolders() ? 54 : 104
            tableView.setContentOffset(CGPoint(x: 0, y: yOffset), animated: false)
            return -1
        }
        return index - 1
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
}
