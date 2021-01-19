//
//  CustomUINavigationController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import Resolver

@objc final class CustomUINavigationController: UINavigationController {
    @Injected private var settings: Settings
    
    override var shouldAutorotate: Bool {
        !(settings.isRotationLockEnabled && UIDevice.current.orientation != .portrait)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Make ourselves our own delegate to automatically fix view controllers going under the navigation bar
        delegate = self
    }
}

extension CustomUINavigationController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        // Prevent view controllers from going under the navigation bar
        viewController.edgesForExtendedLayout = []
        
        // Customizing the more tab controller
        if !(viewController.navigationController is CustomUINavigationController) {
            SceneDelegate.shared.tabBarController?.customizeMoreTabTableView()
        }
    }
}
