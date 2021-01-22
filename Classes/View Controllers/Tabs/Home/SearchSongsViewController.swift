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

enum SearchType: Int {
    case artists = 0
    case albums  = 1
    case songs   = 2
}

final class SearchSongsViewController: UIViewController {
    @Injected private var store: Store
    @Injected private var settings: Settings
    @Injected private var jukebox: Jukebox
    @Injected private var playQueue: PlayQueue
    
    var serverId = Settings.shared().currentServerId
    
    var query = ""
    var searchType = SearchType.songs
    
    var folderArtists = [FolderArtist]()
    var folderAlbums = [FolderAlbum]()
    var songs = [Song]()
    
    private let tableView = UITableView()
    
    private var offset = 0
    private var isMoreResults = true
    private var isLoading = false
    private var dataTask: URLSessionDataTask?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Colors.background
        setupDefaultTableView(tableView)
    }
    
    deinit {
        dataTask?.cancel()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addShowPlayerButton()
    }
    
    private func loadMoreResults() {
        guard !isLoading else { return }
        
        isLoading = true
        offset += 20
        
        var action = ""
        var parameters = [String: Any]()
        if settings.currentServer?.isNewSearchSupported == true {
            action = "search2"
            let queryString = "\(query)*"
            switch searchType {
            case .artists:
                parameters = ["artistCount": 20,
                              "albumCount": 0,
                              "songCount": 0,
                              "query": queryString,
                              "artistOffset": offset]
            case .albums:
                parameters = ["artistCount": 0,
                              "albumCount": 20,
                              "songCount": 0,
                              "query": queryString,
                              "albumOffset": offset]
            case .songs:
                parameters = ["artistCount": 0,
                              "albumCount": 0,
                              "songCount": 20,
                              "query": queryString,
                              "songOffset": offset]
            }
        } else {
            action = "search"
            parameters = ["count": 20, "any": query, "offset": offset]
        }
        
        // TODO: implement this
        // TODO: Don't hard code server id
        guard let request = URLRequest(serverId: serverId, subsonicAction: action, parameters: parameters) else {
            DDLogError("[SearchSongsViewController] failed to create URLRequest to load more results with action \(action) and parameters \(parameters)")
            isMoreResults = false
            tableView.reloadData()
            isLoading = false
            return
        }
        
        dataTask = AbstractAPILoader.sharedSession.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            if let data = data {
                let parser = SearchXMLParser(serverId: self.serverId, data: data)
                switch self.searchType {
                case .artists:
                    if parser.folderArtists.count == 0 {
                        self.isMoreResults = false
                    } else {
                        self.folderArtists.append(contentsOf: parser.folderArtists)
                    }
                case .albums:
                    if parser.folderAlbums.count == 0 {
                        self.isMoreResults = false
                    } else {
                        self.folderAlbums.append(contentsOf: parser.folderAlbums)
                    }
                case .songs:
                    if parser.folderAlbums.count == 0 {
                        self.isMoreResults = false
                    } else {
                        self.songs.append(contentsOf: parser.songs)
                    }
                }
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.isLoading = false
                }
            } else if let error = error {
                if self.settings.isPopupsEnabled {
                    DispatchQueue.main.async {
                        let message = "There was an error performing the search.\n\nError: \(error.localizedDescription)"
                        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                        alert.addCancelAction(title: "OK")
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
        dataTask?.resume()
    }
}

extension SearchSongsViewController: UITableViewConfiguration {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch searchType {
        case .artists: return folderArtists.count + 1
        case .albums: return folderAlbums.count + 1
        case .songs: return songs.count + 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch searchType {
        case .artists:
            if indexPath.row < folderArtists.count {
                let cell = tableView.dequeueUniversalCell()
                cell.show(cached: false, number: false, art: false, secondary: false, duration: false)
                cell.update(model: folderArtists[indexPath.row])
                return cell
            }
        case .albums:
            if indexPath.row < folderAlbums.count {
                let cell = tableView.dequeueUniversalCell()
                cell.show(cached: false, number: false, art: true, secondary: false, duration: false)
                cell.update(model: folderAlbums[indexPath.row])
                return cell
            }
        case .songs:
            if indexPath.row < songs.count {
                let cell = tableView.dequeueUniversalCell()
                cell.show(cached: true, number: false, art: true, secondary: true, duration: true)
                cell.update(model: songs[indexPath.row])
                return cell
            }
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
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch searchType {
        case .artists:
            if indexPath.row < folderArtists.count {
                let controller = FolderAlbumViewController(folderArtist: folderArtists[indexPath.row])
                pushViewControllerCustom(controller)
                return
            }
        case .albums:
            if indexPath.row < folderAlbums.count {
                let controller = FolderAlbumViewController(folderAlbum: folderAlbums[indexPath.row])
                pushViewControllerCustom(controller)
                return
            }
        case .songs:
            if indexPath.row < songs.count {
                if let song = store.playSong(position: indexPath.row, songs: songs), !song.isVideo {
                    showPlayer()
                }
                return
            }
        }
        
        // Loading cell
        tableView.deselectRow(at: indexPath, animated: false)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        switch searchType {
        case .artists:
            if indexPath.row < folderArtists.count {
                return SwipeAction.downloadAndQueueConfig(model: folderArtists[indexPath.row])
            }
        case .albums:
            if indexPath.row < folderAlbums.count {
                return SwipeAction.downloadAndQueueConfig(model: folderAlbums[indexPath.row])
            }
        case .songs:
            if indexPath.row < songs.count {
                return SwipeAction.downloadAndQueueConfig(model: songs[indexPath.row])
            }
        }
        return nil
    }
}
