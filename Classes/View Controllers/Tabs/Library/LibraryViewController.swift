//
//  LibraryViewController.swift
//  iSub Release
//
//  Created by Benjamin Baron on 2/4/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import Tabman
import Pageboy

final class LibraryViewController: TabmanViewController {
    private enum TabType: Int, CaseIterable {
        case folders = 0, artists, bookmarks
        var name: String {
            switch self {
            case .folders:   return "Folders"
            case .artists:   return "Artists"
            case .bookmarks: return "Bookmarks"
            }
        }
    }

    @Injected private var settings: Settings
    @Injected private var analytics: Analytics
    
    private let buttonBar = TMBar.ButtonBar()
    private var controllerCache = [TabType: UIViewController]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Colors.background
        title = "Library"
        
        // Setup ButtonBar
        isScrollEnabled = false
        dataSource = self
        buttonBar.backgroundView.style = .clear
        buttonBar.layout.transitionStyle = .snap
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addBar(buttonBar, dataSource: self, at: .navigationItem(item: navigationItem))
        analytics.log(event: .libraryTab)
    }
    
    private func viewController(index: Int) -> UIViewController? {
        guard let type = TabType(rawValue: index) else { return nil }
        
        if let viewController = controllerCache[type] {
            return viewController
        } else {
            let controller: UIViewController
            switch type {
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
            }
            controllerCache[type] = controller
            return controller
        }
    }
}

extension LibraryViewController: PageboyViewControllerDataSource, TMBarDataSource {
    func numberOfViewControllers(in pageboyViewController: PageboyViewController) -> Int {
        return TabType.count
    }

    func viewController(for pageboyViewController: PageboyViewController, at index: PageboyViewController.PageIndex) -> UIViewController? {
        return viewController(index: index)
    }

    func defaultPage(for pageboyViewController: PageboyViewController) -> PageboyViewController.Page? {
        return nil
    }

    func barItem(for bar: TMBar, at index: Int) -> TMBarItemable {
        return TMBarItem(title: TabType(rawValue: index)?.name ?? "")
    }
}
