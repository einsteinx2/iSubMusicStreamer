//
//  DownloadedTagArtistViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/20/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import SnapKit
import CocoaLumberjackSwift

// TODO: Make sure to call the getArtist API for all downloaded songs or they won't show up here
final class DownloadedTagArtistViewController: AbstractDownloadsViewController {
    @Injected private var store: Store
    @Injected private var settings: Settings
        
    private let downloadedTagArtist: DownloadedTagArtist
    private var downloadedTagAlbums = [DownloadedTagAlbum]()
    
    init(downloadedTagArtist: DownloadedTagArtist) {
        self.downloadedTagArtist = downloadedTagArtist
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = downloadedTagArtist.name
    }
    
    @objc override func reloadTable() {
        downloadedTagAlbums = store.downloadedTagAlbums(downloadedTagArtist: downloadedTagArtist)
        super.reloadTable()
    }
}

extension DownloadedTagArtistViewController: UITableViewConfiguration {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return downloadedTagAlbums.count
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueUniversalCell()
        cell.show(cached: false, number: false, art: true, secondary: true, duration: false)
        cell.update(model: downloadedTagAlbums[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let controller = DownloadedTagAlbumViewController(downloadedTagAlbum: downloadedTagAlbums[indexPath.row])
        pushViewControllerCustom(controller)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        // TODO: implement this
        return nil
    }
}
