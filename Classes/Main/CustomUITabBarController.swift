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
        case home = 0, library, player, playlists, downloads
    }
    
    @Injected private var settings: Settings
    
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
            case .home:
                controller = CustomUINavigationController(rootViewController: HomeViewController())
                controller.tabBarItem = UITabBarItem(title: "Home", image: UIImage(named: "tabbaricon-home"), tag: type.rawValue)
            case .library:
                controller = CustomUINavigationController(rootViewController: LibraryViewController())
                controller.tabBarItem = UITabBarItem(title: "Library", image: UIImage(named: "tabbaricon-folders"), tag: type.rawValue)
                self.libraryTab = controller
            case .player:
                controller = CustomUINavigationController(rootViewController: PlayerViewController())
                controller.setNavigationBarHidden(true, animated: false)
                let imageConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular, scale: .large)
                let image: UIImage?
                if #available(iOS 14.0, *) {
                    image = UIImage(systemName: "music.quarternote.3", withConfiguration: imageConfig)
                } else {
                    image = UIImage(systemName: "music.note", withConfiguration: imageConfig)
                }
                controller.tabBarItem = UITabBarItem(title: "Player", image: image, tag: type.rawValue)
            case .playlists:
                controller = CustomUINavigationController(rootViewController: PlaylistsViewController())
                controller.tabBarItem = UITabBarItem(title: "Playlists", image: UIImage(named: "tabbaricon-playlists"), tag: type.rawValue)
            case .downloads:
                controller = CustomUINavigationController(rootViewController: DownloadsViewController())
                controller.tabBarItem = UITabBarItem(title: "Downloads", image: UIImage(named: "tabbaricon-cache"), tag: 0)
            }
            controllers.append(controller)
        }
        self.viewControllers = controllers
    }
    
    func popLibraryTab() {
        libraryTab?.popToRootViewController(animated: false)
    }
}
