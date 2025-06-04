//
//  SearchAllViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import Tabman
import Pageboy

final class SearchAllViewController: TabmanViewController {
    private enum TabType {
        case folderArtists, folderAlbums, tagArtists, tagAlbums, songs
        var name: String {
            switch self {
            case .folderArtists, .tagArtists: return "Artists"
            case .folderAlbums, .tagAlbums: return "Albums"
            case .songs:   return "Songs"
            }
        }
    }

    @Injected private var settings: SavedSettings
    @Injected private var analytics: Analytics
    
    let serverId: Int
    let query: String
    let searchType: AsyncSearchLoader.SearchType
    
    let folderArtists: [FolderArtist]
    let folderAlbums: [FolderAlbum]
    let tagArtists: [TagArtist]
    let tagAlbums: [TagAlbum]
    let songs: [Song]
    
    private var tabs = [TabType]()
    private let buttonBar = TMBar.ButtonBar()
    private var controllerCache = [TabType: UIViewController]()
    
    init(serverId: Int, query: String, searchType: AsyncSearchLoader.SearchType, folderArtists: [FolderArtist] = [], folderAlbums: [FolderAlbum] = [], tagArtists: [TagArtist] = [], tagAlbums: [TagAlbum] = [], songs: [Song] = []) {
        self.serverId = serverId
        self.query = query
        self.searchType = searchType
        self.folderArtists = folderArtists
        self.folderAlbums = folderAlbums
        self.tagArtists = tagArtists
        self.tagAlbums = tagAlbums
        self.songs = songs
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("unimplemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Colors.background
        
        if folderArtists.count > 0 { tabs.append(.folderArtists) }
        if tagArtists.count > 0    { tabs.append(.tagArtists) }
        if folderAlbums.count > 0  { tabs.append(.folderAlbums) }
        if tagAlbums.count > 0     { tabs.append(.tagAlbums) }
        if songs.count > 0         { tabs.append(.songs) }
        
        // Setup ButtonBar
        isScrollEnabled = false
        dataSource = self
        buttonBar.backgroundView.style = .clear
        buttonBar.layout.transitionStyle = .snap
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addBar(buttonBar, dataSource: self, at: .navigationItem(item: navigationItem))
        analytics.log(event: .searchAll)
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    private func viewController(index: Int) -> UIViewController? {
        guard index < tabs.count else { return nil }
        
        let type = tabs[index]
        if let viewController = controllerCache[type] {
            return viewController
        } else {
            let controller: SearchSongsViewController
            switch type {
            case .folderArtists:
                controller = SearchSongsViewController(serverId: serverId, query: query, searchType: .folder, searchItemType: .artists, folderArtists: folderArtists)
            case .folderAlbums:
                controller = SearchSongsViewController(serverId: serverId, query: query, searchType: .folder, searchItemType: .albums, folderAlbums: folderAlbums)
            case .tagArtists:
                controller = SearchSongsViewController(serverId: serverId, query: query, searchType: .tag, searchItemType: .artists, tagArtists: tagArtists)
            case .tagAlbums:
                controller = SearchSongsViewController(serverId: serverId, query: query, searchType: .tag, searchItemType: .albums, tagAlbums: tagAlbums)
            case .songs:
                controller = SearchSongsViewController(serverId: serverId, query: query, searchType: searchType, searchItemType: .songs, songs: songs)
            }
            controllerCache[type] = controller
            return controller
        }
    }
}

extension SearchAllViewController: PageboyViewControllerDataSource, TMBarDataSource {
    func numberOfViewControllers(in pageboyViewController: PageboyViewController) -> Int {
        return tabs.count
    }

    func viewController(for pageboyViewController: PageboyViewController, at index: PageboyViewController.PageIndex) -> UIViewController? {
        return viewController(index: index)
    }

    func defaultPage(for pageboyViewController: PageboyViewController) -> PageboyViewController.Page? {
        return nil
    }

    func barItem(for bar: TMBar, at index: Int) -> TMBarItemable {
        return TMBarItem(title: tabs[index].name)
    }
}
