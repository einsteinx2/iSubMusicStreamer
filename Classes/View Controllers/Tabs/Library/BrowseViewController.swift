//
//  BrowseViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit
import Resolver

final class BrowseViewController: CustomUITableViewController {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
    @Injected private var analytics: Analytics
    @Injected private var playbackCoordinator: PlaybackCoordinator

    var serverId: Int { settings.currentServerId }

    private enum Row {
        case recentlyAdded, recentlyPlayed, frequentlyPlayed, randomAlbums
        case shuffleAll
        case nowPlayingOnServer
        case serverChat

        var title: String {
            switch self {
            case .recentlyAdded:      return "Recently Added"
            case .recentlyPlayed:     return "Recently Played"
            case .frequentlyPlayed:   return "Frequently Played"
            case .randomAlbums:       return "Random Albums"
            case .shuffleAll:         return "Shuffle All"
            case .nowPlayingOnServer: return "Now Playing on Server"
            case .serverChat:         return "Server Chat"
            }
        }

        var accessibilityId: String {
            switch self {
            case .recentlyAdded:      return AccessibilityId.browseRecentlyAdded
            case .recentlyPlayed:     return AccessibilityId.browseRecentlyPlayed
            case .frequentlyPlayed:   return AccessibilityId.browseFrequentlyPlayed
            case .randomAlbums:       return AccessibilityId.browseRandomAlbums
            case .shuffleAll:         return AccessibilityId.browseShuffleAll
            case .nowPlayingOnServer: return AccessibilityId.browseNowPlaying
            case .serverChat:         return AccessibilityId.browseChat
            }
        }

        var quickAlbumsModifier: QuickAlbumsModifier? {
            switch self {
            case .recentlyAdded:    return .newest
            case .recentlyPlayed:   return .recent
            case .frequentlyPlayed: return .frequent
            case .randomAlbums:     return .random
            default:                return nil
            }
        }
    }

    private var rows = [Row]()
    private var loaderTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Colors.background
        title = "Browse"
        setupDefaultTableView(tableView)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadRows), name: Notifications.serverSwitched)
    }

    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
        loaderTask?.cancel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadRows()
        analytics.log(event: .browseTab)
    }

    // Every row talks to the server, so they all dim and stop responding offline
    // (see CustomUITableViewController.handleOfflineMode)
    override func isAvailableOffline(at indexPath: IndexPath) -> Bool {
        return false
    }

    @objc private func reloadRows() {
        rows = [.recentlyAdded, .recentlyPlayed, .frequentlyPlayed, .randomAlbums, .shuffleAll, .nowPlayingOnServer]
        if settings.isChatEnabled {
            rows.append(.serverChat)
        }
        tableView.reloadData()
    }

    private func loadQuickAlbums(modifier: QuickAlbumsModifier, title: String) {
        loaderTask?.cancel()
        loaderTask = Task {
            do {
                HUD.show(closeHandler: cancelLoad)
                defer {
                    HUD.hide()
                }

                let folderAlbums = try await AsyncQuickAlbumsLoader(serverId: serverId, modifier: modifier).load()
                let controller = QuickAlbumsViewController(modifier: modifier, folderAlbums: folderAlbums, title: title)
                self.pushViewControllerCustom(controller)
            } catch {
                if self.settings.isPopupsEnabled && !error.isCanceled {
                    let alert = UIAlertController(title: "Error", message: "There was an error grabbing the album list.\n\nError: \(error.localizedDescription)", preferredStyle: .alert)
                    alert.addOKAction()
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func shuffleAll(sourceCell: UITableViewCell?) {
        let mediaFolders = store.mediaFolders(serverId: serverId)
        if mediaFolders.count <= 2 {
            // 2 media folders means the "All Media Folders" option plus one folder aka only 1 actual media folder
            // If we don't have any media folders loaded, just shuffle all media folders since that always works
            performServerShuffle(mediaFolderId: MediaFolder.allFoldersId)
        } else {
            let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            sheet.addAction(title: "All Media Folders", style: .default) { action in
                self.performServerShuffle(mediaFolderId: MediaFolder.allFoldersId)
            }
            for mediaFolder in mediaFolders {
                if mediaFolder.id != MediaFolder.allFoldersId {
                    sheet.addAction(title: mediaFolder.name, style: .default) { action in
                        self.performServerShuffle(mediaFolderId: mediaFolder.id)
                    }
                }
            }
            sheet.addCancelAction()
            if let popoverPresentationController = sheet.popoverPresentationController, let sourceCell {
                // Fix exception on iPad
                popoverPresentationController.sourceView = sourceCell
                popoverPresentationController.sourceRect = sourceCell.bounds
            }
            present(sheet, animated: true, completion: nil)
        }
    }

    private func performServerShuffle(mediaFolderId: Int) {
        loaderTask?.cancel()
        loaderTask = Task {
            do {
                HUD.show(closeHandler: cancelLoad)
                defer {
                    HUD.hide()
                }

                let songs = try await AsyncServerShuffleLoader(serverId: serverId, mediaFolderId: mediaFolderId).load()
                playbackCoordinator.play(songs: songs, position: 0)
                NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
            } catch {
                if settings.isPopupsEnabled, !error.isCanceled {
                    let alert = UIAlertController(title: "Error", message: "There was an error creating the server shuffle list.\n\nThe connection could not be created", preferredStyle: .alert)
                    alert.addOKAction()
                    present(alert, animated: true)
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

extension BrowseViewController: UITableViewConfiguration {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rows[indexPath.row]
        let cell = tableView.dequeueUniversalCell()
        cell.show(downloaded: false, number: false, art: false, secondary: false, duration: false)
        cell.update(primaryText: row.title)
        cell.accessibilityIdentifier = row.accessibilityId
        handleOfflineMode(cell: cell, at: indexPath)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !settings.isOfflineMode else { return }

        let row = rows[indexPath.row]
        if let modifier = row.quickAlbumsModifier {
            loadQuickAlbums(modifier: modifier, title: row.title)
            return
        }
        switch row {
        case .shuffleAll:
            shuffleAll(sourceCell: tableView.cellForRow(at: indexPath))
        case .nowPlayingOnServer:
            pushViewControllerCustom(NowPlayingViewController())
        case .serverChat:
            pushViewControllerCustom(ChatViewController())
        default:
            break
        }
    }
}
