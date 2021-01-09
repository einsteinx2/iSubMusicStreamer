//
//  SearchAllViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit

@objc class SearchAllViewController: UITableViewController {
    private var cellNames = [String]()

    var folderArtists = [FolderArtist]()
    var folderAlbums = [FolderAlbum]()
    var songs = [Song]()
    var query = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if folderArtists.count > 0 { cellNames.append("Artists") }
        if folderAlbums.count > 0 { cellNames.append("Albums") }
        if songs.count > 0 { cellNames.append("Songs") }
        
        tableView.rowHeight = Defines.rowHeight
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cellNames.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as! UniversalTableViewCell
        cell.update(primaryText: cellNames[indexPath.row], secondaryText: nil)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let controller = SearchSongsViewController(nibName: "SearchSongsViewController", bundle: nil)
        switch cellNames[indexPath.row] {
        case "Artists":
            controller.folderArtists = NSMutableArray(array: folderArtists)
            controller.searchType = ISMSSearchSongsSearchType_Artists
        case "Albums":
            controller.folderAlbums = NSMutableArray(array: folderAlbums)
            controller.searchType = ISMSSearchSongsSearchType_Albums
        case "Songs":
            controller.songs = NSMutableArray(array: songs)
            controller.searchType = ISMSSearchSongsSearchType_Songs
        default: break
        }
        controller.query = query
        pushCustom(controller)
    }
}
