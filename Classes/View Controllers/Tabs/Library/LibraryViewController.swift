//
//  LibraryViewController.swift
//  iSub Release
//
//  Created by Benjamin Baron on 2/4/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver

final class LibraryViewController: UIViewController {
    @Injected private var settings: Settings
    
    private var controllerCache = [Int: UIViewController]()
    
    private let tableView = UITableView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Colors.background
        title = "Library"
        
        setupDefaultTableView(tableView)
        
        // TODO: implement this - make a function like setupDefaultTableView to add this and the two buttons in viewWillAppear automatically when in the tab bar and the controller is the root of the nav stack (do this for all view controllers to remove the duplicate code)
        // Or maybe just make a superclass that sets up the default table and handles all this
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(addURLRefBackButton), name: UIApplication.didBecomeActiveNotification)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addURLRefBackButton()
        addShowPlayerButton()
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }
}

extension LibraryViewController: UITableViewConfiguration {
    private enum RowType: Int, CaseIterable {
        case folders = 0, artists, bookmarks
        var name: String {
            switch self {
            case .folders: return "Folders"
            case .artists: return "Artists"
            case .bookmarks: return "Bookmarks"
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return RowType.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        if let rowType = RowType(rawValue: indexPath.row) {
            cell.update(primaryText: rowType.name)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let controller = controllerCache[indexPath.row] {
            pushViewControllerCustom(controller)
            return
        }
        
        let controller: UIViewController?
        switch RowType(rawValue: indexPath.row) {
        case .folders:
            let foldersMediaFolderId = settings.rootFoldersSelectedFolderId?.intValue ?? MediaFolder.allFoldersId
            let foldersDataModel = FolderArtistsViewModel(serverId: settings.currentServerId, mediaFolderId: foldersMediaFolderId)
            controller = ArtistsViewController(dataModel: foldersDataModel)
        case .artists:
            let artistsMediaFolderId = settings.rootArtistsSelectedFolderId?.intValue ?? MediaFolder.allFoldersId
            let artistsDataModel = TagArtistsViewModel(serverId: settings.currentServerId, mediaFolderId: artistsMediaFolderId)
            controller = ArtistsViewController(dataModel: artistsDataModel)
        case .bookmarks:
            controller = BookmarksViewController()
        default:
            controller = nil
        }
        
        if let controller = controller {
            controllerCache[indexPath.row] = controller
            pushViewControllerCustom(controller)
        }
    }
}
