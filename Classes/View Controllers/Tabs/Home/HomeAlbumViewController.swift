//
//  HomeAlbumViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/19/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver

final class HomeAlbumViewController: UIViewController {
    @Injected private var settings: SavedSettings
    
    var serverId: Int { (Resolver.resolve() as SavedSettings).currentServerId }
    
    let modifier: QuickAlbumsModifier
    var folderAlbums: [FolderAlbum]
    
    private let tableView = UITableView()
    
    private var isMoreAlbums: Bool
    private var isLoading = false
    private var offset = 0
    private var loaderTask: Task<Void, Never>?
    
    init(modifier: QuickAlbumsModifier, folderAlbums: [FolderAlbum], title: String) {
        self.modifier = modifier
        self.folderAlbums = folderAlbums
        self.isMoreAlbums = folderAlbums.count >= AsyncSearchLoader.searchItemCount
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Colors.background
        setupDefaultTableView(tableView)
    }
    
    deinit {
        loaderTask?.cancel()
    }
    
    private func loadMoreResults() {
        guard !isLoading else { return }
        
        isLoading = true
        offset += 20
        
        loaderTask = Task {
            do {
                defer {
                    tableView.reloadData()
                    isLoading = false
                }
                
                let responseFolderAlbums = try await AsyncQuickAlbumsLoader(serverId: serverId, modifier: modifier, offset: offset).load()
                if responseFolderAlbums.count == 0 {
                    isMoreAlbums = false
                } else {
                    folderAlbums.append(contentsOf: responseFolderAlbums)
                }
            } catch {
                if self.settings.isPopupsEnabled {
                    let message = "There was an error performing the search.\n\nError: \(error.localizedDescription)"
                    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                    alert.addOKAction()
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
}

extension HomeAlbumViewController: UITableViewConfiguration {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return folderAlbums.count + 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row < folderAlbums.count {
            let cell = tableView.dequeueUniversalCell()
            cell.show(downloaded: false, number: false, art: true, secondary: true, duration: false)
            cell.update(model: folderAlbums[indexPath.row])
            return cell
        } else {
            // This is the last cell and there could be more results, load the next 20 songs;
            let cell = UITableViewCell(style: .default, reuseIdentifier: "HomeAlbumLoadCell")
            cell.backgroundColor = .systemBackground
            if isMoreAlbums {
                cell.textLabel?.text = "Loading more results...";
                let indicator = UIActivityIndicatorView(style: .medium)
                indicator.center = CGPoint(x: 300, y: tableView.rowHeight / 2.0)
                indicator.autoresizingMask = .flexibleLeftMargin
                cell.addSubview(indicator)
                indicator.startAnimating()
                loadMoreResults()
            } else {
                cell.textLabel?.text = "No more results"
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row < folderAlbums.count {
            let controller = FolderAlbumViewController(folderAlbum: folderAlbums[indexPath.row])
            pushViewControllerCustom(controller)
        } else {
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if indexPath.row < folderAlbums.count {
            return SwipeAction.downloadAndQueueConfig(model: folderAlbums[indexPath.row])
        }
        return nil
    }
}
