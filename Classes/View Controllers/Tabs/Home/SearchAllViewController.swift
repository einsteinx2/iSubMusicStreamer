//
//  SearchAllViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit

@objc class SearchAllViewController: UIViewController {
    private var cellNames = [String]()
    
    private let tableView = UITableView()

    var folderArtists = [FolderArtist]()
    var folderAlbums = [FolderAlbum]()
    var songs = [Song]()
    var query = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if folderArtists.count > 0 { cellNames.append("Artists") }
        if folderAlbums.count > 0 { cellNames.append("Albums") }
        if songs.count > 0 { cellNames.append("Songs") }
        setupDefaultTableView(tableView)
    }
}
 
extension SearchAllViewController: UITableViewConfiguration {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cellNames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.update(primaryText: cellNames[indexPath.row], secondaryText: nil)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let controller = SearchSongsViewController()
        switch cellNames[indexPath.row] {
        case "Artists":
            controller.folderArtists = folderArtists
            controller.searchType = .artists
        case "Albums":
            controller.folderAlbums = folderAlbums
            controller.searchType = .albums
        case "Songs":
            controller.songs = songs
            controller.searchType = .songs
        default: break
        }
        controller.query = query
        pushViewControllerCustom(controller)
    }
}
