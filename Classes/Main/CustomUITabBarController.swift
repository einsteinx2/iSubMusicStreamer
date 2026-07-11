//
//  CustomUITabBarController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver

final class CustomUITabBarController: UITabBarController {
    enum TabType: Int, CaseIterable {
        case library = 0, playlists, player, downloads, settings
    }
    
    @Injected private var settings: SavedSettings
    
    private(set) var libraryTab: CustomUINavigationController?
    
    override var shouldAutorotate: Bool {
        !(settings.isRotationLockEnabled && UIDevice.current.orientation != .portrait)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        createTabs()
    }

    private func createTabs() {
        var controllers = [UIViewController]()
        for type in TabType.allCases {
            let controller: CustomUINavigationController
            switch type {
            case .library:
                controller = CustomUINavigationController(rootViewController: LibraryViewController())
                controller.tabBarItem = UITabBarItem(title: "Library", image: UIImage(named: "tabbaricon-folders"), tag: type.rawValue)
                controller.tabBarItem.accessibilityIdentifier = AccessibilityId.tabLibrary
                self.libraryTab = controller
            case .playlists:
                controller = CustomUINavigationController(rootViewController: PlaylistsViewController())
                controller.tabBarItem = UITabBarItem(title: "Playlists", image: UIImage(named: "tabbaricon-playlists"), tag: type.rawValue)
                controller.tabBarItem.accessibilityIdentifier = AccessibilityId.tabPlaylists
            case .player:
                controller = CustomUINavigationController(rootViewController: PlayerViewController())
                controller.setNavigationBarHidden(true, animated: false)
                let imageConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular, scale: .large)
                let image = UIImage(systemName: "music.quarternote.3", withConfiguration: imageConfig)
                controller.tabBarItem = UITabBarItem(title: "Player", image: image, tag: type.rawValue)
                controller.tabBarItem.accessibilityIdentifier = AccessibilityId.tabPlayer
            case .downloads:
                controller = CustomUINavigationController(rootViewController: DownloadsViewController())
                controller.tabBarItem = UITabBarItem(title: "Downloads", image: UIImage(named: "tabbaricon-cache"), tag: type.rawValue)
                controller.tabBarItem.accessibilityIdentifier = AccessibilityId.tabDownloads
            case .settings:
                controller = CustomUINavigationController()
                // One operation: on first run this is root + server list (see
                // SettingsCoordinator.makeInitialViewControllers)
                controller.setViewControllers(SettingsCoordinator().makeInitialViewControllers(), animated: false)
                let imageConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular, scale: .large)
                let image = UIImage(systemName: "gearshape.fill", withConfiguration: imageConfig)
                controller.tabBarItem = UITabBarItem(title: "Settings", image: image, tag: type.rawValue)
                controller.tabBarItem.accessibilityIdentifier = AccessibilityId.tabSettings
            }
            controllers.append(controller)
        }
        self.viewControllers = controllers
    }
    
    func popLibraryTab(animated: Bool = false) {
        libraryTab?.popToRootViewController(animated: animated)
    }
}
