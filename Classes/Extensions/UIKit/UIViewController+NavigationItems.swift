//
//  UIViewController+NavigationItems.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver

extension UIViewController {
    private var settings: Settings { Resolver.resolve() }
    
    @objc func addURLRefBackButton() {
        if AppDelegate.shared.referringAppUrl != nil && SceneDelegate.shared.tabBarController?.selectedIndex != 4 {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: AppDelegate.shared, action: #selector(AppDelegate.backToReferringApp))
        }
    }
    
    @objc func addShowPlayerButton() {
        navigationItem.rightBarButtonItem = nil
        if settings.showPlayerIcon {
//            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "music.quarternote.3"), style: .plain, target: self, action: #selector(showPlayer))
        }
    }
}
