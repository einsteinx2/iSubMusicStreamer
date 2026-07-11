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
        case folders = 0, artists, bookmarks, browse
        var name: String {
            switch self {
            case .folders:   return "Folders"
            case .artists:   return "Artists"
            case .bookmarks: return "Bookmarks"
            case .browse:    return "Browse"
            }
        }
    }

    @Injected private var settings: SavedSettings
    @Injected private var analytics: Analytics

    private let buttonBar = TMBar.ButtonBar()
    private var controllerCache = [TabType: UIViewController]()

    private let searchController = UISearchController(searchResultsController: nil)
    private var loaderTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Colors.background
        title = "Library"

        // Setup ButtonBar
        isScrollEnabled = false
        dataSource = self
        buttonBar.backgroundView.style = .clear
        buttonBar.layout.transitionStyle = .snap

        // Server search lives in the search bar slot below the nav bar (the Tabman
        // button bar occupies the title view, so the two coexist)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Server Search"
        searchController.searchBar.delegate = self
        searchController.searchBar.accessibilityIdentifier = AccessibilityId.librarySearchBar
        // Scroll-linked hiding is unreliable with paged Tabman children, so keep the
        // bar always visible instead
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        if !settings.isOfflineMode {
            navigationItem.searchController = searchController
        }

        NotificationCenter.addObserverOnMainThread(self, selector: #selector(configureSearchScope), name: Notifications.serverSwitched)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(didEnterOnlineMode), name: Notifications.didEnterOnlineMode)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(didEnterOfflineMode), name: Notifications.didEnterOfflineMode)
    }

    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
        loaderTask?.cancel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addBar(buttonBar, dataSource: self, at: .navigationItem(item: navigationItem))
        configureSearchScope()
        analytics.log(event: .libraryTab)
    }

    // Search is server-only, so the whole search bar disappears offline (a visible but
    // disabled field just looks broken)
    @objc private func didEnterOnlineMode() {
        navigationItem.searchController = searchController
    }

    @objc private func didEnterOfflineMode() {
        searchController.isActive = false
        navigationItem.searchController = nil
    }

    @objc private func configureSearchScope() {
        let isTagSearchSupported = settings.currentServer?.isTagSearchSupported ?? false
        // The scope bar only shows while the search bar is active
        searchController.searchBar.scopeButtonTitles = isTagSearchSupported ? ["Folders", "Tags"] : nil
    }

    private func viewController(index: Int) -> UIViewController? {
        guard let type = TabType(rawValue: index) else { return nil }
        
        if let viewController = controllerCache[type] {
            return viewController
        } else {
            let controller: UIViewController
            switch type {
            case .folders:
                let foldersMediaFolderId = settings.rootFoldersSelectedFolderId
                let foldersDataModel = ArtistsViewModel(serverId: settings.currentServerId, mediaFolderId: foldersMediaFolderId, type: .folders)
                controller = ArtistsViewController(dataModel: foldersDataModel)
            case .artists:
                let artistsMediaFolderId = settings.rootArtistsSelectedFolderId
                let artistsDataModel = ArtistsViewModel(serverId: settings.currentServerId, mediaFolderId: artistsMediaFolderId, type: .tags)
                controller = ArtistsViewController(dataModel: artistsDataModel)
            case .bookmarks:
                controller = BookmarksViewController()
            case .browse:
                controller = BrowseViewController()
            }
            controllerCache[type] = controller
            return controller
        }
    }
}

extension LibraryViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let query = searchBar.text, !query.isEmpty else { return }

        var searchType = AsyncSearchLoader.SearchType.old
        if settings.currentServer?.isTagSearchSupported ?? false {
            searchType = searchBar.selectedScopeButtonIndex == 0 ? .folder : .tag
        }

        let serverId = settings.currentServerId
        loaderTask?.cancel()
        loaderTask = Task {
            do {
                HUD.show(closeHandler: cancelLoad)
                defer {
                    HUD.hide()
                }

                let responseData = try await AsyncSearchLoader(serverId: serverId, searchType: searchType, searchItemType: .all, query: query).load()
                let controller: UIViewController
                if searchType == .old {
                    controller = SearchSongsViewController(serverId: serverId, query: query, searchType: searchType, searchItemType: .songs, songs: responseData.songs)
                } else {
                    controller = SearchAllViewController(serverId: serverId, query: query, searchType: searchType, folderArtists: responseData.folderArtists, folderAlbums: responseData.folderAlbums, tagArtists: responseData.tagArtists, tagAlbums: responseData.tagAlbums, songs: responseData.songs)
                }
                // A push during the search UI's dismissal transition gets dropped, so
                // dismiss first and push from the completion
                if searchController.isActive {
                    searchController.dismiss(animated: true) {
                        self.pushViewControllerCustom(controller)
                    }
                } else {
                    self.pushViewControllerCustom(controller)
                }
            } catch {
                if self.settings.isPopupsEnabled, !error.isCanceled {
                    let alert = UIAlertController(title: "Error", message: "There was an error completing the search.\n\nError: \(error.localizedDescription)", preferredStyle: .alert)
                    alert.addOKAction()
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func cancelLoad() {
        HUD.hide()
        loaderTask?.cancel()
        loaderTask = nil
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
