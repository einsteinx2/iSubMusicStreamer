//
//  PadMenuViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 11/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

@objc class PadMenuViewController: UIViewController {
    private let tableContainer = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let playerController = PlayerViewController()
    private var cellContents = [(imageName: String, text: String)]()
    private var isFirstLoad = true
    private var lastSelectedRow = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor(named: "isubBackgroundColor")
        
        loadCellContents()
        
        view.addSubview(playerController.view)
        playerController.view.snp.makeConstraints { make in
            make.height.equalTo(500)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        view.addSubview(tableContainer)
        tableContainer.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalTo(playerController.view.snp.top)
        }
        
        tableView.register(PadMenuTableCell.self, forCellReuseIdentifier: PadMenuTableCell.reuseId)
        tableView.rowHeight = 44
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableContainer.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.leading.trailing.top.bottom.equalToSuperview()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if UIApplication.orientation().isLandscape {
            let fade = CAGradientLayer()
            fade.frame = CGRect(x: 0, y: 0, width: tableContainer.frame.size.width, height: tableContainer.frame.size.height)
            fade.colors = [UIColor.black.cgColor, UIColor.clear.cgColor]
            fade.locations = [0.9, 1.0]
            tableContainer.layer.mask = fade
            tableView.isScrollEnabled = true
            tableView.showsVerticalScrollIndicator = true
        } else {
            tableContainer.layer.mask = nil
            tableView.isScrollEnabled = false
            tableView.showsVerticalScrollIndicator = false
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if isFirstLoad {
            isFirstLoad = false
            showHome()
        }
    }
    
    @objc func toggleOfflineMode() {
        isFirstLoad = true
        loadCellContents()
        viewDidAppear(true)
    }
    
    @objc func loadCellContents() {
        cellContents.removeAll()
        
        if AppDelegate.shared().referringAppUrl != nil {
            cellContents.append((imageName: "back-tabbaricon", text: "Back"))
        }
        
        if Settings.shared().isOfflineMode {
            cellContents.append((imageName: "settings-tabbaricon", text: "Settings"))
            cellContents.append((imageName: "folders-tabbaricon", text: "Folders"))
            cellContents.append((imageName: "genres-tabbaricon", text: "Genres"))
            cellContents.append((imageName: "playlists-tabbaricon", text: "Playlists"))
            cellContents.append((imageName: "bookmarks-tabbaricon", text: "Bookmarks"))
        } else {
            cellContents.append((imageName: "settings-tabbaricon", text: "Settings"))
            cellContents.append((imageName: "home-tabbaricon", text: "Home"))
            cellContents.append((imageName: "folders-tabbaricon", text: "Folders"))
            cellContents.append((imageName: "playlists-tabbaricon", text: "Playlists"))
            cellContents.append((imageName: "cache-tabbaricon", text: "Cache"))
            cellContents.append((imageName: "bookmarks-tabbaricon", text: "Bookmarks"))
            cellContents.append((imageName: "playing-tabbaricon", text: "Playing"))
            cellContents.append((imageName: "chat-tabbaricon", text: "Chat"))
            
            if Settings.shared().isSongsTabEnabled {
                cellContents.append((imageName: "genres-tabbaricon", text: "Genres"))
                cellContents.append((imageName: "albums-tabbaricon", text: "Albums"))
                cellContents.append((imageName: "songs-tabbaricon", text: "Songs"))
            }
        }
        
        tableView.reloadData()
    }
    
    @objc func showSettings() {
        let isShowingBackCell = AppDelegate.shared().referringAppUrl != nil
        let indexPath = IndexPath(row: isShowingBackCell ? 1 : 0, section: 0)
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
        
        // TODO: Is this hack still necessary?
        tableView(tableView, didSelectRowAt: indexPath)
    }
    
    @objc func showHome() {
        let isShowingBackCell = AppDelegate.shared().referringAppUrl != nil
        let indexPath = IndexPath(row: isShowingBackCell ? 2 : 1, section: 0)
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
        
        // TODO: Is this hack still necessary?
        tableView(tableView, didSelectRowAt: indexPath)
    }
    
    private func showController(indexPath: IndexPath) {
        // If we have the back button displayed, subtract 1 from the row to get the correct action
        let row = AppDelegate.shared().referringAppUrl == nil ? indexPath.row : indexPath.row - 1
        
        // Present the view controller
        var controller: UIViewController?
        if Settings.shared().isOfflineMode {
            switch row {
            case 0: controller = ServerListViewController(nibName: "ServerListViewController", bundle: nil)
            case 1: controller = CacheOfflineFoldersViewController(nibName: "CacheOfflineFoldersViewController", bundle: nil)
            case 2: controller = GenresViewController(nibName: "GenresViewController", bundle: nil)
            case 3: controller = PlaylistsViewController(nibName: "PlaylistsViewController", bundle: nil)
            case 4: controller = BookmarksViewController(nibName: "BookmarksViewController", bundle: nil)
            default: controller = nil
            }
        } else {
            switch row {
            case 0: controller = ServerListViewController(nibName: "ServerListViewController", bundle: nil)
            case 1: controller = HomeViewController(nibName: "HomeViewController", bundle: nil)
            case 2: controller = FoldersViewController(nibName: "FoldersViewController", bundle: nil)
            case 3: controller = PlaylistsViewController(nibName: "PlaylistsViewController", bundle: nil)
            case 4: controller = CacheViewController(nibName: "CacheViewController", bundle: nil)
            case 5: controller = BookmarksViewController(nibName: "BookmarksViewController", bundle: nil)
            case 6: controller = PlayingViewController(nibName: "PlayingViewController", bundle: nil)
            case 7: controller = ChatViewController(nibName: "ChatViewController", bundle: nil)
            case 8: controller = GenresViewController(nibName: "GenresViewController", bundle: nil)
            case 9: controller = AllAlbumsViewController(nibName: "AllAlbumsViewController", bundle: nil)
            case 10: controller = AllSongsViewController(nibName: "AllSongsViewController", bundle: nil)
            default: controller = nil
            }
        }
        
        if let controller = controller, let padRootViewController = parent as? PadRootViewController {
            padRootViewController.switchContentViewController(controller: controller)
        }
        lastSelectedRow = indexPath.row
    }
}

extension PadMenuViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cellContents.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PadMenuTableCell.reuseId) as! PadMenuTableCell
        let contents = cellContents[indexPath.row]
        cell.imageView?.image = UIImage(named: contents.imageName)
        cell.textLabel?.text = contents.text
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Handle the special case of the back button / ref url
        if let referringAppUrl = AppDelegate.shared().referringAppUrl, indexPath.row == 0 {
            // Fix the cell highlighting
            // NOTE: Is this still necessary?
            tableView.deselectRow(at: indexPath, animated: false)
            tableView.selectRow(at: IndexPath(row: lastSelectedRow, section: 0), animated: false, scrollPosition: .none)
            
            // Go back to the other app
            UIApplication.shared.open(referringAppUrl)
            return
        }
        
        EX2Dispatch.runInMainThread(afterDelay: 0.05) {
            self.showController(indexPath: indexPath)
        }
    }
}
