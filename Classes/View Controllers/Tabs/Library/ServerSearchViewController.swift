//
//  ServerSearchViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import Resolver

// Dedicated server search page, reached from the Library tab's Browse page. Hosts the
// search field with Folders/Tags scope buttons (when the server supports tag search)
// and pushes the results screens onto the same navigation stack.
final class ServerSearchViewController: UIViewController {
    @Injected private var settings: SavedSettings
    @Injected private var store: Store

    private let searchController = UISearchController(searchResultsController: nil)
    private var loaderTask: Task<Void, Never>?

    private let hintStack = UIStackView()
    private let hintImageView = UIImageView(image: UIImage(systemName: "magnifyingglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 42, weight: .light)))
    private let hintLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Colors.background
        title = "Server Search"

        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search your server's library"
        searchController.searchBar.delegate = self
        searchController.searchBar.accessibilityIdentifier = AccessibilityId.librarySearchBar
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true

        hintImageView.tintColor = .secondaryLabel
        hintImageView.contentMode = .scaleAspectFit
        hintLabel.text = "Search for artists, albums, and songs\non your server"
        hintLabel.numberOfLines = 0
        hintLabel.textAlignment = .center
        hintLabel.textColor = .secondaryLabel
        hintLabel.font = .preferredFont(forTextStyle: .body)
        hintStack.axis = .vertical
        hintStack.alignment = .center
        hintStack.spacing = 12
        hintStack.addArrangedSubviews([hintImageView, hintLabel])
        view.addSubview(hintStack)
        hintStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().multipliedBy(0.7)
            make.leading.greaterThanOrEqualToSuperview().offset(20)
            make.trailing.lessThanOrEqualToSuperview().offset(-20)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // In the Combined Library the Tags scope appears when ANY server supports tag
        // search; tag-incapable servers just sit out that scope
        let isCombined = settings.isCombinedContext
        let isTagSearchSupported = isCombined
            ? store.servers().contains { $0.isTagSearchSupported }
            : settings.currentServer?.isTagSearchSupported ?? false
        // The scope bar only shows while the search bar is active
        searchController.searchBar.scopeButtonTitles = isTagSearchSupported ? ["Folders", "Tags"] : nil

        searchController.searchBar.placeholder = isCombined ? "Search all of your servers" : "Search your server's library"
        hintLabel.text = isCombined
            ? "Search for artists, albums, and songs\nacross all of your servers"
            : "Search for artists, albums, and songs\non your server"
    }

    deinit {
        loaderTask?.cancel()
    }
}

extension ServerSearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let query = searchBar.text, !query.isEmpty else { return }

        if settings.isCombinedContext {
            performCombinedSearch(query: query, useTagScope: searchBar.selectedScopeButtonIndex == 1)
            return
        }

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
                self.pushSearchResults(controller)
            } catch {
                if self.settings.isPopupsEnabled, !error.isCanceled {
                    let alert = UIAlertController(title: "Error", message: "There was an error completing the search.\n\nError: \(error.localizedDescription)", preferredStyle: .alert)
                    alert.addOKAction()
                    self.present(alert, animated: true)
                }
            }
        }
    }

    // Every server searched at once, honoring each server's capabilities: the Tags
    // scope asks only tag-capable servers; the Folders scope uses search2 where
    // supported and the old search (songs only) elsewhere. Results interleave so
    // every server stays visible near the top; further pages go through per-server
    // pagers seeded past this first fetch.
    private func performCombinedSearch(query: String, useTagScope: Bool) {
        let servers = store.servers()
        let participants: [Server]
        var searchTypesByServerId = [Int: AsyncSearchLoader.SearchType]()
        if useTagScope {
            participants = servers.filter { $0.isTagSearchSupported }
            for server in participants { searchTypesByServerId[server.id] = .tag }
        } else {
            participants = servers
            for server in participants { searchTypesByServerId[server.id] = server.isNewSearchSupported ? .folder : .old }
        }

        loaderTask?.cancel()
        loaderTask = Task {
            HUD.show(closeHandler: cancelLoad)
            defer {
                HUD.hide()
            }

            let result = await ServerFanOut.run(servers: participants) { server in
                try await AsyncSearchLoader(serverId: server.id, searchType: searchTypesByServerId[server.id] ?? .folder, searchItemType: .all, query: query).load()
            }
            if result.isTotalFailure, let failure = result.failures.first {
                if settings.isPopupsEnabled {
                    let alert = UIAlertController(title: "Error", message: "There was an error completing the search.\n\nError: \(failure.error.localizedDescription)", preferredStyle: .alert)
                    alert.addOKAction()
                    present(alert, animated: true)
                }
                return
            }

            func merged<Item>(_ keyPath: KeyPath<SearchAPIResponseData, [Item]>) -> [Item] {
                ServerFanOutResult(successes: result.successes.map { .init(server: $0.server, value: $0.value[keyPath: keyPath]) },
                                   failures: []).interleaved()
            }
            // A server whose first page for a field came back short has no more of
            // that field; only full-page servers keep paging
            @MainActor func pager<Item>(_ keyPath: KeyPath<SearchAPIResponseData, [Item]>,
                                        fetchPage: @escaping @Sendable (Server, Int) async throws -> [Item]) -> PerServerPager<Item> {
                let counts = Dictionary(uniqueKeysWithValues: result.successes.map { ($0.server.id, $0.value[keyPath: keyPath].count) })
                let pagingServers = result.successes.map(\.server).filter { (counts[$0.id] ?? 0) >= AsyncSearchLoader.searchItemCount }
                return PerServerPager(servers: pagingServers, pageSize: AsyncSearchLoader.searchItemCount,
                                      startingOffsets: counts, fetchPage: fetchPage)
            }

            let searchTypes = searchTypesByServerId
            let combinedPagerFactory: @MainActor (AsyncSearchLoader.SearchItemType) -> SearchResultsPager? = { itemType in
                switch itemType {
                case .artists where useTagScope:
                    return .tagArtists(pager(\.tagArtists) { server, offset in
                        try await AsyncSearchLoader(serverId: server.id, searchType: .tag, searchItemType: .artists, query: query, offset: offset).load().tagArtists
                    })
                case .artists:
                    return .folderArtists(pager(\.folderArtists) { server, offset in
                        try await AsyncSearchLoader(serverId: server.id, searchType: .folder, searchItemType: .artists, query: query, offset: offset).load().folderArtists
                    })
                case .albums where useTagScope:
                    return .tagAlbums(pager(\.tagAlbums) { server, offset in
                        try await AsyncSearchLoader(serverId: server.id, searchType: .tag, searchItemType: .albums, query: query, offset: offset).load().tagAlbums
                    })
                case .albums:
                    return .folderAlbums(pager(\.folderAlbums) { server, offset in
                        try await AsyncSearchLoader(serverId: server.id, searchType: .folder, searchItemType: .albums, query: query, offset: offset).load().folderAlbums
                    })
                case .songs:
                    return .songs(pager(\.songs) { server, offset in
                        try await AsyncSearchLoader(serverId: server.id, searchType: searchTypes[server.id] ?? .folder, searchItemType: .songs, query: query, offset: offset).load().songs
                    })
                default:
                    return nil
                }
            }

            let controller = SearchAllViewController(serverId: settings.currentServerId, query: query,
                                                     searchType: useTagScope ? .tag : .folder,
                                                     folderArtists: merged(\.folderArtists),
                                                     folderAlbums: merged(\.folderAlbums),
                                                     tagArtists: merged(\.tagArtists),
                                                     tagAlbums: merged(\.tagAlbums),
                                                     songs: merged(\.songs),
                                                     combinedPagerFactory: combinedPagerFactory)
            pushSearchResults(controller)
        }
    }

    // A push during the search UI's dismissal transition gets dropped, so dismiss
    // first and push from the completion
    private func pushSearchResults(_ controller: UIViewController) {
        if searchController.isActive {
            searchController.dismiss(animated: true) {
                self.pushViewControllerCustom(controller)
            }
        } else {
            self.pushViewControllerCustom(controller)
        }
    }

    private func cancelLoad() {
        HUD.hide()
        loaderTask?.cancel()
        loaderTask = nil
    }
}
