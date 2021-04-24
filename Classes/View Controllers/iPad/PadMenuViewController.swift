//
//  PadMenuViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 11/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import Resolver

final class PadMenuViewController: UIViewController {
    enum TabType: Int, CaseIterable {
        case settings = 0, home, library, playlists, downloads, back
    }
    
    @Injected private var settings: Settings
    
    private let tableContainer = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let playerController = PlayerViewController()
    private var cellContents = [(imageName: String, text: String)]()
    private var isFirstLoad = true
    private var lastSelectedRow = -1
    private var cachedTabs = [TabType: UINavigationController]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.overrideUserInterfaceStyle = .dark
        view.backgroundColor = Colors.background
        
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
        if UIApplication.orientation.isLandscape {
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
    
    func toggleOfflineMode() {
        isFirstLoad = true
        loadCellContents()
        viewDidAppear(true)
    }
    
    func loadCellContents() {
        cellContents.removeAll()
        if AppDelegate.shared.referringAppUrl != nil {
            cellContents.append((imageName: "tabbaricon-back", text: "Back"))
        }
        cellContents.append((imageName: "tabbaricon-settings", text: "Settings"))
        cellContents.append((imageName: "tabbaricon-home", text: "Home"))
        cellContents.append((imageName: "tabbaricon-folders", text: "Library"))
        cellContents.append((imageName: "tabbaricon-playlists", text: "Playlists"))
        cellContents.append((imageName: "tabbaricon-cache", text: "Downloads"))
        tableView.reloadData()
    }
    
    func showSettings() {
        let isShowingBackCell = AppDelegate.shared.referringAppUrl != nil
        let indexPath = IndexPath(row: isShowingBackCell ? 1 : 0, section: 0)
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
        
        // TODO: Is this hack still necessary?
        tableView(tableView, didSelectRowAt: indexPath)
    }
    
    func showHome() {
        let isShowingBackCell = AppDelegate.shared.referringAppUrl != nil
        let indexPath = IndexPath(row: isShowingBackCell ? 2 : 1, section: 0)
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
        
        // TODO: Is this hack still necessary?
        tableView(tableView, didSelectRowAt: indexPath)
    }
    
    private func showController(indexPath: IndexPath) {
        // If we have the back button displayed, subtract 1 from the row to get the correct action
        let row = AppDelegate.shared.referringAppUrl == nil ? indexPath.row : indexPath.row - 1
        guard let type = TabType(rawValue: row) else { return }
        
        // Present the view controller
        var navController: UINavigationController? = nil
        if let cachedController = cachedTabs[type] {
            navController = cachedController
        } else {
            var controller: UIViewController? = nil
            switch type {
            case .settings:  controller = SettingsViewController()
            case .home:      controller = HomeViewController()
            case .library:   controller = LibraryViewController()
            case .playlists: controller = PlaylistsViewController()
            case .downloads: controller = DownloadsViewController()
            default: break
            }
            if let controller = controller {
                navController = CustomUINavigationController(rootViewController: controller)
                cachedTabs[type] = navController
            }
        }
        
        if let navController = navController {
            if let padRootViewController = parent as? PadRootViewController {
                padRootViewController.switchContentViewController(controller: navController)
            } else if let splitViewController = parent as? UISplitViewController {
                splitViewController.showDetailViewController(navController, sender: self)
            }
        }
        lastSelectedRow = indexPath.row
    }
    
    func popLibraryTab(animated: Bool = false) {
        if let navController = cachedTabs[.library] {
            navController.popToRootViewController(animated: animated)
        }
    }
}

extension PadMenuViewController: UITableViewConfiguration {
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
        if let referringAppUrl = AppDelegate.shared.referringAppUrl, indexPath.row == 0 {
            // Fix the cell highlighting
            // NOTE: Is this still necessary?
            tableView.deselectRow(at: indexPath, animated: false)
            tableView.selectRow(at: IndexPath(row: lastSelectedRow, section: 0), animated: false, scrollPosition: .none)
            
            // Go back to the other app
            UIApplication.shared.open(referringAppUrl)
            return
        }
        
        DispatchQueue.main.async(after: 0.05) {
            self.showController(indexPath: indexPath)
        }
    }
}
