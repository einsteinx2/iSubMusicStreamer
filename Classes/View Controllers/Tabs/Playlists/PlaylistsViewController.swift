//
//  PlaylistsViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Tabman
import Pageboy
import Resolver

final class PlaylistsViewController: TabmanViewController {
    private enum TabType: Int, CaseIterable {
        case playQueue = 0, local, server
        var name: String {
            switch self {
            case .playQueue: return "Play Queue"
            case .local:     return "Local"
            case .server:    return "Server"
            }
        }
    }
    
    @Injected private var analytics: Analytics
    
    private let buttonBar = TMBar.ButtonBar()
    private var controllerCache = [TabType: UIViewController]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Colors.background
        title = "Playlists"

        // Setup ButtonBar
        isScrollEnabled = false
        dataSource = self
        buttonBar.backgroundView.style = .clear
        buttonBar.layout.transitionStyle = .snap
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addBar(buttonBar, dataSource: self, at: .navigationItem(item: navigationItem))
        analytics.log(event: .playlistsTab)
    }
    
    private func viewController(index: Int) -> UIViewController? {
        guard let type = TabType(rawValue: index) else { return nil }
        
        if let viewController = controllerCache[type] {
            return viewController
        } else {
            let controller: UIViewController
            switch type {
            case .playQueue: controller = PlayQueueViewController()
            case .local:     controller = LocalPlaylistsViewController()
            case .server:    controller = ServerPlaylistsViewController()
            }
            controllerCache[type] = controller
            return controller
        }
    }
}

extension PlaylistsViewController: PageboyViewControllerDataSource, TMBarDataSource {
    func numberOfViewControllers(in pageboyViewController: PageboyViewController) -> Int {
        return TabType.count
    }

    func viewController(for pageboyViewController: PageboyViewController, at index: PageboyViewController.PageIndex) -> UIViewController? {
        return viewController(index: index)
    }

    func defaultPage(for pageboyViewController: PageboyViewController) -> PageboyViewController.Page? {
        return nil
    }

    func barItem(for bar: TMBar, at index: Int) -> TMBarItemable {
        return TMBarItem(title: TabType(rawValue: index)?.name ?? "")
    }
}
