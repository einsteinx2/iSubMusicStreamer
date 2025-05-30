//
//  ServersViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/25/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver
import SnapKit
import CocoaLumberjackSwift
import CwlCatchException

final class ServersViewController: UIViewController {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
    @Injected private var streamManager: StreamManager
    @Injected private var downloadQueue: DownloadQueue
    @Injected private var player: BassPlayer
    @Injected private var playQueue: PlayQueue
    
    private let tableView = UITableView()
    private var originalBackButtonItem: UIBarButtonItem?
    
    private var servers = [Server]()
    private var serverToEdit: Server?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Colors.background
        title = "Servers"
        
        servers = store.servers()
        
        setupDefaultTableView(tableView)
        tableView.allowsSelectionDuringEditing = true
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(reloadTable), name: Notifications.reloadServerList)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(showBackButton), name: Notifications.showBackButton)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(switchServer(notification:)), name: Notifications.switchServer)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Store reference to the original back button, but with a custom action
        originalBackButtonItem = parent?.navigationItem.leftBarButtonItem
        
        showBackButton()
        parent?.navigationItem.rightBarButtonItem = editButtonItem
        
        if servers.count == 0 {
            addAction()
        }
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
        if editing {
            parent?.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addAction))
        } else {
            showBackButton()
        }
    }
    
    @objc private func reloadTable() {
        servers = store.servers()
        tableView.reloadData()
    }
    
    @objc private func showBackButton() {
        guard !isEditing else { return }
        
        if let parent = parent, let first = navigationController?.viewControllers.first, parent === first {
            parent.navigationItem.leftBarButtonItem = nil
        } else {
            parent?.navigationItem.leftBarButtonItem = originalBackButtonItem
        }
    }
    
    @objc private func addAction() {
        let controller = ServerEditViewController()
        controller.modalPresentationStyle = .formSheet
        if UIDevice.isPad {
            SceneDelegate.shared.padRootViewController?.present(controller, animated: true, completion: nil)
        } else {
            present(controller, animated: true, completion: nil)
        }
    }
    
    @objc private func switchServer(notification: Notification) {
        setEditing(false, animated: false)
        reloadTable()
        serverToEdit = nil
        switchServer()
    }
    
    // TODO: implement this - refactor this and make sure it actually works
    private func switchServer() {
        if let parent = parent, let first = navigationController?.viewControllers.first, parent === first, !UIDevice.isPad {
            navigationController?.view.removeFromSuperview()
        } else {
            navigationController?.popToRootViewController(animated: true)
            
            guard SceneDelegate.shared.isNetworkReachable else { return }
            
            // Cancel any caching
            streamManager.removeAllStreams()
            
            // Stop any playing song and remove old tab bar controller from window
            player.stop()
            settings.isRecover = false
            settings.isJukeboxEnabled = false
            
            if settings.isOfflineMode {
                settings.isOfflineMode = false
                
                if UIDevice.isPad {
                    SceneDelegate.shared.padRootViewController?.menuViewController.toggleOfflineMode()
                } else if let window = view.window {
                    for subview in window.subviews {
                        subview.removeFromSuperview()
                    }
                }
            }
            
            // Reset the data model
            _ = playQueue.clear()
            _ = downloadQueue.clear()
            
            // Reset the tabs
            if !UIDevice.isPad, let viewControllers = SceneDelegate.shared.tabBarController?.viewControllers  {
                for controller in viewControllers {
                    if let controller = controller as? UINavigationController {
                        controller.popToRootViewController(animated: true)
                    }
                }
            }
            
            NotificationCenter.postOnMainThread(name: Notifications.serverSwitched)
        }
    }
}

extension ServersViewController: UITableViewConfiguration {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return servers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "ServerCell")
        
        let server = servers[indexPath.row]
        
        cell.textLabel?.text = server.url.absoluteString
        cell.textLabel?.textColor = .label
        cell.textLabel?.font = .boldSystemFont(ofSize: 20)
        
        cell.detailTextLabel?.text = "username: \(server.username)"
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.font = .systemFont(ofSize: 15)
        
        var image: UIImage? = nil// UIImage(named: "server-subsonic")
        if let currentServer = settings.currentServer, currentServer == server {
            if traitCollection.userInterfaceStyle == .dark {
                image = UIImage(named: "current-server")?.withTintColor(.white)
            } else {
                image = UIImage(named: "current-server")
            }
        }
        cell.imageView?.image = image
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let server = servers[indexPath.row]
        serverToEdit = server
        
        if isEditing {
            let controller = ServerEditViewController()
            controller.modalPresentationStyle = .formSheet
            controller.serverToEdit = server
            present(controller, animated: true, completion: nil)
        } else {
            HUD.show(message: "Checking Server")
            StatusLoader(server: server, delegate: self).startLoad()
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    // TODO: Delete all server resources (maybe do it in the Store)
    // TODO: Automatically switch to another server or show the add server screen
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        
        let server = servers[indexPath.row]
        _ = store.deleteServer(id: server.id)
        servers = store.servers()
        
        // Alert user to select new default server if they deleting the default
        if settings.isPopupsEnabled, let currentServer = settings.currentServer, currentServer == server {
            let message = "Make sure to select a new server"
            let alert = UIAlertController(title: "Notice", message: message, preferredStyle: .alert)
            alert.addOKAction()
            present(alert, animated: true, completion: nil)
        }
        
        do {
            try catchExceptionAsError {
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        } catch {
            tableView.reloadData()
        }
    }
}

extension ServersViewController: APILoaderDelegate {
    func loadingFinished(loader: APILoader?) {
        HUD.hide()
        DDLogInfo("[ServersViewController] server verification passed, hiding loading screen")
        
        // Update server properties
        if let statusLoader = loader as? StatusLoader {
            serverToEdit?.isVideoSupported = statusLoader.isVideoSupported
            serverToEdit?.isNewSearchSupported = statusLoader.isNewSearchSupported
            if let serverToEdit {
                _ = store.add(server: serverToEdit)
            }
        }
        
        // Switch to the server
        settings.currentServer = serverToEdit
        switchServer()
    }
    
    func loadingFailed(loader: APILoader?, error: Error?) {
        HUD.hide()
        DDLogError("[ServersViewController] server verification failed, hiding loading screen")
        
        var message: String
        if let error = error as? SubsonicError, case .badCredentials = error {
            message = "Either your username or password is incorrect\n\n☆☆ Choose a server to return to online mode. ☆☆\n\nError code \(error.code):\n\(error.localizedDescription)"
        } else {
            message = "Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\n☆☆ Choose a server to return to online mode. ☆☆"
            if let error {
                message += "\n\nError: \(error)"
            }
        }
        
        let alert = UIAlertController(title: "Server Unavailable", message: message, preferredStyle: .alert)
        alert.addOKAction()
        present(alert, animated: true, completion: nil)
    }
}
