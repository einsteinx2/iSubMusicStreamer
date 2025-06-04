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
    let searchType: AsyncSearchLoader.SearchType
    let searchItemType: AsyncSearchLoader.SearchItemType
    
    private(set) var folderArtists: [FolderArtist]
    private(set) var folderAlbums: [FolderAlbum]
    private(set) var tagArtists: [TagArtist]
    private(set) var tagAlbums: [TagAlbum]
    private(set) var songs: [Song]
        
    private var offset = 0
    private var isMoreResults = true
    private var isLoading = false
//    private var searchLoader: SearchLoader
    private var loaderTask: Task<Void, Never>?
    
    init(serverId: Int, query: String, searchType: AsyncSearchLoader.SearchType, searchItemType: AsyncSearchLoader.SearchItemType, folderArtists: [FolderArtist] = [], folderAlbums: [FolderAlbum] = [], tagArtists: [TagArtist] = [], tagAlbums: [TagAlbum] = [], songs: [Song] = []) {
        self.serverId = serverId
        self.query = query
        self.searchType = searchType
        self.searchItemType = searchItemType
        self.folderArtists = folderArtists
        self.folderAlbums = folderAlbums
        self.tagArtists = tagArtists
        self.tagAlbums = tagAlbums
        self.songs = songs
//        self.searchLoader = SearchLoader(serverId: serverId, searchType: searchType, searchItemType: searchItemType, query: query)
        
        switch searchItemType {
        case .artists:
            let artists: [Any] = searchType == .folder ? folderArtists : tagArtists
            isMoreResults = artists.count >= AsyncSearchLoader.searchItemCount
        case .albums:
            let albums: [Any] = searchType == .folder ? folderAlbums : tagAlbums
            isMoreResults = albums.count >= AsyncSearchLoader.searchItemCount
        case .songs:
            isMoreResults = songs.count >= AsyncSearchLoader.searchItemCount
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
        loaderTask?.cancel()
//        searchLoader.cancelLoad()
//        searchLoader.callback = nil
    }
    
    private func loadMoreResults() {
        guard !isLoading else { return }
        isLoading = true
        
        offset += AsyncSearchLoader.searchItemCount
        loaderTask = Task {
            do {
                defer {
                    isLoading = false
                }
                
                let responseData = try await AsyncSearchLoader(serverId: serverId, searchType: searchType, searchItemType: searchItemType, query: query, offset: offset).load()
                switch self.searchItemType {
                case .artists:
                    if searchType == .folder {
                        folderArtists.append(contentsOf: responseData.folderArtists)
                        if responseData.folderArtists.count == 0 {
                            isMoreResults = false
                        }
                    } else {
                        tagArtists.append(contentsOf: responseData.tagArtists)
                        if responseData.tagArtists.count == 0 {
                            isMoreResults = false
                        }
                    }
                case .albums:
                    if searchType == .folder {
                        folderAlbums.append(contentsOf: responseData.folderAlbums)
                        if responseData.folderAlbums.count == 0 {
                            isMoreResults = false
                        }
                    } else {
                        tagAlbums.append(contentsOf: responseData.tagAlbums)
                        if responseData.tagAlbums.count == 0 {
                            isMoreResults = false
                        }
                    }
                case .songs:
                    songs.append(contentsOf: responseData.songs)
                    if responseData.songs.count == 0 {
                        isMoreResults = false
                    }
                default:
                    break
                }
                tableView.reloadData()
            } catch {
                if settings.isPopupsEnabled, !error.isCanceled {
                    self.isMoreResults = false
                    self.tableView.reloadData()
                    
                    // TODO: Verify if it's still necessary to use \(error.localizedDescription) or if I can just use \(error)
                    let message = "There was an error performing the search.\n\nError: \(error.localizedDescription)"
                    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                    alert.addOKAction()
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
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
