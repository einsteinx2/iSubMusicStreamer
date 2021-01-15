//
//  PadMenuViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 11/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

@objc final class PadMenuViewController: UIViewController {
    private let tableContainer = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let playerController = PlayerViewController()
    private var cellContents = [(imageName: String, text: String)]()
    private var isFirstLoad = true
    private var lastSelectedRow = -1
    private var cachedTabs = [String: UINavigationController]()
    
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
            cellContents.append((imageName: "tabbaricon-back", text: "Back"))
        }
        
        if Settings.shared().isOfflineMode {
            cellContents.append((imageName: "tabbaricon-settings", text: "Settings"))
            cellContents.append((imageName: "tabbaricon-folders", text: "Folders"))
            cellContents.append((imageName: "tabbaricon-genres", text: "Genres"))
            cellContents.append((imageName: "tabbaricon-playlists", text: "Playlists"))
            cellContents.append((imageName: "tabbaricon-bookmarks", text: "Bookmarks"))
        } else {
            cellContents.append((imageName: "tabbaricon-settings", text: "Settings"))
            cellContents.append((imageName: "tabbaricon-home", text: "Home"))
            cellContents.append((imageName: "tabbaricon-folders", text: "Folders"))
            cellContents.append((imageName: "tabbaricon-playlists", text: "Playlists"))
            cellContents.append((imageName: "tabbaricon-cache", text: "Cache"))
            cellContents.append((imageName: "tabbaricon-bookmarks", text: "Bookmarks"))
            cellContents.append((imageName: "tabbaricon-playing", text: "Playing"))
            cellContents.append((imageName: "tabbaricon-chat", text: "Chat"))
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
    
    // TODO: implement this
    private func showController(indexPath: IndexPath) {
        // If we have the back button displayed, subtract 1 from the row to get the correct action
        let row = AppDelegate.shared().referringAppUrl == nil ? indexPath.row : indexPath.row - 1
        
        // Present the view controller
        var controller: UINavigationController?
        if Settings.shared().isOfflineMode {
            switch row {
            case 0:
                if let cachedController = cachedTabs["ServerListViewController"] {
                    controller = cachedController
                } else {
                    controller = CustomUINavigationController(rootViewController: ServerListViewController(nibName: "ServerListViewController", bundle: nil))
                    cachedTabs["ServerListViewController"] = controller
                }
//            case 1:
//                if let cachedController = cachedTabs["CacheOfflineFoldersViewController"] {
//                    controller = cachedController
//                } else {
//                    controller = CustomUINavigationController(rootViewController: CacheOfflineFoldersViewController(nibName: "CacheOfflineFoldersViewController", bundle: nil))
//                    cachedTabs["CacheOfflineFoldersViewController"] = controller
//                }
//            case 2:
//                if let cachedController = cachedTabs["GenresViewController"] {
//                    controller = cachedController
//                } else {
//                    controller = CustomUINavigationController(rootViewController: GenresViewController(nibName: "GenresViewController", bundle: nil))
//                    cachedTabs["GenresViewController"] = controller
//                }
            case 3:
                if let cachedController = cachedTabs["PlaylistsViewController"] {
                    controller = cachedController
                } else {
                    controller = CustomUINavigationController(rootViewController: PlaylistsViewController(nibName: "PlaylistsViewController", bundle: nil))
                    cachedTabs["PlaylistsViewController"] = controller
                }
            case 4:
                if let cachedController = cachedTabs["BookmarksViewController"] {
                    controller = cachedController
                } else {
                    controller = CustomUINavigationController(rootViewController: BookmarksViewController(nibName: "BookmarksViewController", bundle: nil))
                    cachedTabs["BookmarksViewController"] = controller
                }
            default: controller = nil
            }
        } else {
            switch row {
            case 0:
                if let cachedController = cachedTabs["ServerListViewController"] {
                    controller = cachedController
                } else {
                    controller = CustomUINavigationController(rootViewController: ServerListViewController(nibName: "ServerListViewController", bundle: nil))
                    cachedTabs["ServerListViewController"] = controller
                }
            case 1:
                if let cachedController = cachedTabs["HomeViewController"] {
                    controller = cachedController
                } else {
                    controller = CustomUINavigationController(rootViewController: HomeViewController(nibName: "HomeViewController", bundle: nil))
                    cachedTabs["HomeViewController"] = controller
                }
            case 2:
                if let cachedController = cachedTabs["FoldersViewController"] {
                    controller = cachedController
                } else {
                    controller = CustomUINavigationController(rootViewController: FoldersViewController(nibName: "FoldersViewController", bundle: nil))
                    cachedTabs["FoldersViewController"] = controller
                }
            case 3:
                if let cachedController = cachedTabs["PlaylistsViewController"] {
                    controller = cachedController
                } else {
                    controller = CustomUINavigationController(rootViewController: PlaylistsViewController(nibName: "PlaylistsViewController", bundle: nil))
                    cachedTabs["PlaylistsViewController"] = controller
                }
            case 4:
                if let cachedController = cachedTabs["CacheViewController"] {
                    controller = cachedController
                } else {
                    controller = CustomUINavigationController(rootViewController: CacheViewController(nibName: "CacheViewController", bundle: nil))
                    cachedTabs["CacheViewController"] = controller
                }
            case 5:
                if let cachedController = cachedTabs["BookmarksViewController"] {
                    controller = cachedController
                } else {
                    controller = CustomUINavigationController(rootViewController: BookmarksViewController(nibName: "BookmarksViewController", bundle: nil))
                    cachedTabs["BookmarksViewController"] = controller
                }
            case 6:
                if let cachedController = cachedTabs["NowPlayingViewController"] {
                    controller = cachedController
                } else {
                    controller = CustomUINavigationController(rootViewController: NowPlayingViewController(nibName: "NowPlayingViewController", bundle: nil))
                    cachedTabs["NowPlayingViewController"] = controller
                }
            case 7:
                if let cachedController = cachedTabs["ChatViewController"] {
                    controller = cachedController
                } else {
                    controller = CustomUINavigationController(rootViewController: ChatViewController(nibName: "ChatViewController", bundle: nil))
                    cachedTabs["ChatViewController"] = controller
                }
//            case 8:
//                if let cachedController = cachedTabs["GenresViewController"] {
//                    controller = cachedController
//                } else {
//                    controller = CustomUINavigationController(rootViewController: GenresViewController(nibName: "GenresViewController", bundle: nil))
//                    cachedTabs["GenresViewController"] = controller
//                }
//            case 9:
//                if let cachedController = cachedTabs["AllAlbumsViewController"] {
//                    controller = cachedController
//                } else {
//                    controller = CustomUINavigationController(rootViewController: AllAlbumsViewController(nibName: "AllAlbumsViewController", bundle: nil))
//                    cachedTabs["AllAlbumsViewController"] = controller
//                }
//            case 10:
//                if let cachedController = cachedTabs["AllSongsViewController"] {
//                    controller = cachedController
//                } else {
//                    controller = CustomUINavigationController(rootViewController: AllSongsViewController(nibName: "AllSongsViewController", bundle: nil))
//                    cachedTabs["AllSongsViewController"] = controller
//                }
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
