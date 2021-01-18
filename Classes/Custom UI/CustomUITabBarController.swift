//
//  CustomUITabBarController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit

@objc final class CustomUITabBarController: UITabBarController {
    override var shouldAutorotate: Bool {
        !(Settings.shared().isRotationLockEnabled && UIDevice.current.orientation != .portrait)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        ViewObjects.shared().orderMainTabBarController()
        customizeMoreTabTableView()
    }
    
    @objc func customizeMoreTabTableView() {
        moreNavigationController.navigationBar.barStyle = .black
        if let moreController = moreNavigationController.topViewController {
            if let moreTableView = moreController.view as? UITableView {
                moreTableView.backgroundColor = Colors.background
                moreTableView.rowHeight = Defines.rowHeight
                moreTableView.separatorStyle = .none
            }
        }
    }
}
