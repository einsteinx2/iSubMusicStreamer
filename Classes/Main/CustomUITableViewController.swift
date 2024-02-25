//
//  CustomUITableViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 4/24/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver

class CustomUITableViewController: UIViewController {
    @Injected private var settings: SavedSettings
    
    let tableView = UITableView()
    
    // Subclasses can add any subview that should be disabled in offline mode to this array
    var offlineDisabledViews = [UIView]()
    
    // Subclasses should call this at the end of the cellForRow: delegate function before returning the cell
    func handleOfflineMode(cell: UITableViewCell, at indexPath: IndexPath) {
        if settings.isOfflineMode && !isAvailableOffline(at: indexPath) {
            cell.disable()
            cell.contentView.disable()
        } else if !cell.isUserInteractionEnabled {
            cell.enable(useOriginalAlpha: false)
            cell.contentView.enable(useOriginalAlpha: false)
        }
    }
    
    // MARK: Subclass overrides
    
    func tableCellModel(at indexPath: IndexPath) -> TableCellModel? {
        fatalError("All subclasses must implement this method")
    }
    
    func isAvailableOffline(at indexPath: IndexPath) -> Bool {
        if let model = tableCellModel(at: indexPath) {
            return model.isAvailableOffline
        }
        return false
    }
    
    // MARK: Notification Handling
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(didEnterOnlineMode), name: Notifications.didEnterOnlineMode)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(didEnterOfflineMode), name: Notifications.didEnterOfflineMode)
        if settings.isOfflineMode {
            didEnterOfflineMode()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.didEnterOnlineMode)
        NotificationCenter.removeObserverOnMainThread(self, name: Notifications.didEnterOfflineMode)
    }

    @objc private func didEnterOnlineMode() {
        guard !settings.isOfflineMode else { return }
        
        for cell in tableView.visibleCells {
            if !cell.isUserInteractionEnabled {
                cell.enable()
                cell.contentView.enable()
            }
        }
                
        for disabledView in offlineDisabledViews {
            if !disabledView.isUserInteractionEnabled {
                disabledView.enable()
            }
        }
    }
    
    @objc private func didEnterOfflineMode() {
        guard settings.isOfflineMode else { return }
        
        if let indexPaths = tableView.indexPathsForVisibleRows {
            for indexPath in indexPaths {
                if !isAvailableOffline(at: indexPath), let cell = tableView.cellForRow(at: indexPath), cell.isUserInteractionEnabled {
                    cell.disable()
                    cell.contentView.disable()
                }
            }
        }
        
        for disabledView in offlineDisabledViews {
            if disabledView.isUserInteractionEnabled {
                disabledView.disable()
            }
        }
    }
}
