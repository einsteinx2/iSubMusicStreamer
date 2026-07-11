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
        let isTagSearchSupported = settings.currentServer?.isTagSearchSupported ?? false
        // The scope bar only shows while the search bar is active
        searchController.searchBar.scopeButtonTitles = isTagSearchSupported ? ["Folders", "Tags"] : nil
    }

    deinit {
        loaderTask?.cancel()
    }
}

extension ServerSearchViewController: UISearchBarDelegate {
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
