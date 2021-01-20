//
//  DownloadsViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import Resolver

final class DownloadsViewController: AbstractDownloadsViewController {//UIViewController {
    @Injected private var store: Store
        
    // TODO: Separately track downloaded folders, artists, albums, and songs to show the appropriate table cells
    private var downloadedSongsCount = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Downloads"
    }
    
    @objc override func reloadTable() {
        downloadedSongsCount = store.downloadedSongsCount()
        super.reloadTable()
    }
}

extension DownloadsViewController: UITableViewConfiguration {
    private enum RowType: Int {
        case folders = 0
        case artists = 1
        case albums = 2
        case songs = 3
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return downloadedSongsCount > 0 ? 4 : 0
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.show(cached: false, number: false, art: false, secondary: false, duration: false)
        switch RowType(rawValue: indexPath.row) {
        case .folders: cell.update(primaryText: "Folders", secondaryText: nil)
        case .artists: cell.update(primaryText: "Artists", secondaryText: nil)
        case .albums:  cell.update(primaryText: "Albums", secondaryText: nil)
        case .songs:   cell.update(primaryText: "Songs", secondaryText: nil)
        default: break
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let controller: UIViewController?
        switch RowType(rawValue: indexPath.row) {
        case .folders: controller = DownloadedFolderArtistsViewController()
        case .artists: controller = DownloadedTagArtistsViewController()
        case .albums:  controller = DownloadedTagAlbumsViewController()
        case .songs:   controller = DownloadedSongsViewController()
        default: controller = nil
        }
        if let controller = controller {
            pushViewControllerCustom(controller)
        }
    }

}
