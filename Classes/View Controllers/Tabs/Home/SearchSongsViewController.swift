//
//  SearchSongsViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/19/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import CocoaLumberjackSwift

final class SearchSongsViewController: CustomUITableViewController {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
    @Injected private var jukebox: Jukebox
    @Injected private var playQueue: PlayQueue
    
    let serverId: Int
    let query: String
    let searchType: SearchLoader.SearchType
    let searchItemType: SearchLoader.SearchItemType
    
    private(set) var folderArtists: [FolderArtist]
    private(set) var folderAlbums: [FolderAlbum]
    private(set) var tagArtists: [TagArtist]
    private(set) var tagAlbums: [TagAlbum]
    private(set) var songs: [Song]
        
    private var offset = 0
    private var isMoreResults = true
    private var isLoading = false
    private var searchLoader: SearchLoader
    
    init(serverId: Int, query: String, searchType: SearchLoader.SearchType, searchItemType: SearchLoader.SearchItemType, folderArtists: [FolderArtist] = [], folderAlbums: [FolderAlbum] = [], tagArtists: [TagArtist] = [], tagAlbums: [TagAlbum] = [], songs: [Song] = []) {
        self.serverId = serverId
        self.query = query
        self.searchType = searchType
        self.searchItemType = searchItemType
        self.folderArtists = folderArtists
        self.folderAlbums = folderAlbums
        self.tagArtists = tagArtists
        self.tagAlbums = tagAlbums
        self.songs = songs
        self.searchLoader = SearchLoader(serverId: serverId, searchType: searchType, searchItemType: searchItemType, query: query)
        
        switch searchItemType {
        case .artists:
            let artists: [Any] = searchType == .folder ? folderArtists : tagArtists
            isMoreResults = artists.count >= SearchLoader.searchItemCount
        case .albums:
            let albums: [Any] = searchType == .folder ? folderAlbums : tagAlbums
            isMoreResults = albums.count >= SearchLoader.searchItemCount
        case .songs:
            isMoreResults = songs.count >= SearchLoader.searchItemCount
        default:
            isMoreResults = true
        }
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Search Results"
        view.backgroundColor = Colors.background
        setupDefaultTableView(tableView)
    }
    
    deinit {
        searchLoader.cancelLoad()
        searchLoader.callback = nil
    }
    
    private func loadMoreResults() {
        guard !isLoading else { return }
        isLoading = true
        searchLoader.offset += SearchLoader.searchItemCount
        searchLoader.callback = { [weak self] _, success, error in
            guard let self else { return }
            self.isLoading = false
            
            if success {
                switch self.searchItemType {
                case .artists:
                    if self.searchType == .folder {
                        self.folderArtists.append(contentsOf: self.searchLoader.folderArtists)
                        if self.searchLoader.folderArtists.count == 0 {
                            self.isMoreResults = false
                        }
                    } else {
                        self.tagArtists.append(contentsOf: self.searchLoader.tagArtists)
                        if self.searchLoader.tagArtists.count == 0 {
                            self.isMoreResults = false
                        }
                    }
                case .albums:
                    if self.searchType == .folder {
                        self.folderAlbums.append(contentsOf: self.searchLoader.folderAlbums)
                        if self.searchLoader.folderAlbums.count == 0 {
                            self.isMoreResults = false
                        }
                    } else {
                        self.tagAlbums.append(contentsOf: self.searchLoader.tagAlbums)
                        if self.searchLoader.tagAlbums.count == 0 {
                            self.isMoreResults = false
                        }
                    }
                case .songs:
                    self.songs.append(contentsOf: self.searchLoader.songs)
                    if self.searchLoader.songs.count == 0 {
                        self.isMoreResults = false
                    }
                default:
                    break
                }
                self.tableView.reloadData()
            } else if let error = error, self.settings.isPopupsEnabled {
                self.isMoreResults = false
                self.tableView.reloadData()
                
                let message = "There was an error performing the search.\n\nError: \(error.localizedDescription)"
                let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                alert.addOKAction()
                self.present(alert, animated: true, completion: nil)
            }
        }
        searchLoader.startLoad()
    }
    
    override func tableCellModel(at indexPath: IndexPath) -> TableCellModel? {
        switch searchItemType {
        case .artists:
            let artists: [TableCellModel] = searchType == .folder ? folderArtists : tagArtists
            guard indexPath.row < artists.count else { return nil }
            return artists[indexPath.row]
        case .albums:
            let albums: [TableCellModel] = searchType == .folder ? folderAlbums : tagAlbums
            guard indexPath.row < albums.count else { return nil }
            return albums[indexPath.row]
        case .songs:
            guard indexPath.row < songs.count else { return nil }
            return songs[indexPath.row]
        default:
            return nil
        }
    }
}

extension SearchSongsViewController: UITableViewConfiguration {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch searchItemType {
        case .artists: return (searchType == .folder ? folderArtists.count : tagArtists.count) + 1
        case .albums:  return (searchType == .folder ? folderAlbums.count : tagAlbums.count) + 1
        case .songs:   return songs.count + 1
        default:       return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch searchItemType {
        case .artists:
            let artists: [TableCellModel] = searchType == .folder ? folderArtists : tagArtists
            if indexPath.row < artists.count {
                let cell = tableView.dequeueUniversalCell()
                cell.show(downloaded: false, number: false, art: searchType == .tag, secondary: false, duration: false)
                cell.update(model: artists[indexPath.row])
                return cell
            }
        case .albums:
            let albums: [TableCellModel] = searchType == .folder ? folderAlbums : tagAlbums
            if indexPath.row < albums.count {
                let cell = tableView.dequeueUniversalCell()
                cell.show(downloaded: false, number: false, art: true, secondary: false, duration: false)
                cell.update(model: albums[indexPath.row])
                return cell
            }
        case .songs:
            if indexPath.row < songs.count {
                let cell = tableView.dequeueUniversalCell()
                cell.show(downloaded: true, number: false, art: true, secondary: true, duration: true)
                cell.update(model: songs[indexPath.row])
                return cell
            }
        default:
            break
        }
        
        // This is the last cell and there could be more results, load the next 20 songs;
        let cell = UITableViewCell(style: .default, reuseIdentifier: "SearchSongsLoadCell")
        cell.backgroundColor = .systemBackground
        if isMoreResults {
            cell.textLabel?.text = "Loading more results...";
            let indicator = UIActivityIndicatorView(style: .medium)
            indicator.center = CGPoint(x: 300, y: tableView.rowHeight / 2.0)
            indicator.autoresizingMask = .flexibleLeftMargin
            cell.addSubview(indicator)
            indicator.startAnimating()
            loadMoreResults()
        } else if folderArtists.count > 0 || folderAlbums.count > 0 || songs.count > 0 {
            cell.textLabel?.text = "No more search results"
        } else {
            cell.textLabel?.text = "No results"
        }
        
        handleOfflineMode(cell: cell, at: indexPath)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch searchItemType {
        case .artists:
            if searchType == .folder {
                if indexPath.row < folderArtists.count {
                    let controller = FolderAlbumViewController(folderArtist: folderArtists[indexPath.row])
                    pushViewControllerCustom(controller)
                    return
                }
            } else {
                if indexPath.row < tagArtists.count {
                    let controller = TagArtistViewController(tagArtist: tagArtists[indexPath.row])
                    pushViewControllerCustom(controller)
                    return
                }
            }
        case .albums:
            if searchType == .folder {
                if indexPath.row < folderAlbums.count {
                    let controller = FolderAlbumViewController(folderAlbum: folderAlbums[indexPath.row])
                    pushViewControllerCustom(controller)
                    return
                }
            } else {
                if indexPath.row < tagAlbums.count {
                    let controller = TagAlbumViewController(tagAlbum: tagAlbums[indexPath.row])
                    pushViewControllerCustom(controller)
                    return
                }
            }
        case .songs:
            if indexPath.row < songs.count {
                if let song = store.playSong(position: indexPath.row, songs: songs), !song.isVideo {
                    NotificationCenter.postOnMainThread(name: Notifications.showPlayer)
                }
                return
            }
        default:
            break
        }
        
        // Loading cell
        tableView.deselectRow(at: indexPath, animated: false)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        switch searchItemType {
        case .artists:
            let artists: [TableCellModel] = searchType == .folder ? folderArtists : tagArtists
            if indexPath.row < artists.count {
                return SwipeAction.downloadAndQueueConfig(model: artists[indexPath.row])
            }
        case .albums:
            let albums: [TableCellModel] = searchType == .folder ? folderAlbums : tagAlbums
            if indexPath.row < albums.count {
                return SwipeAction.downloadAndQueueConfig(model: albums[indexPath.row])
            }
        case .songs:
            if indexPath.row < songs.count {
                return SwipeAction.downloadAndQueueConfig(model: songs[indexPath.row])
            }
        default:
            break
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        switch searchItemType {
        case .artists:
            let artists: [TableCellModel] = searchType == .folder ? folderArtists : tagArtists
            if indexPath.row < artists.count {
                return contextMenuDownloadAndQueueConfig(model: artists[indexPath.row])
            }
        case .albums:
            let albums: [TableCellModel] = searchType == .folder ? folderAlbums : tagAlbums
            if indexPath.row < albums.count {
                return contextMenuDownloadAndQueueConfig(model: albums[indexPath.row])
            }
        case .songs:
            if indexPath.row < songs.count {
                return contextMenuDownloadAndQueueConfig(model: songs[indexPath.row])
            }
        default:
            break
        }
        return nil
    }
}
