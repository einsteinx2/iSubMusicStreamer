//
//  UIViewController+PushCustom.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit

@objc extension UIViewController {
    func pushViewControllerCustom(_ viewController: UIViewController) {
        if let self = self as? UINavigationController {
            self.pushViewController(viewController, animated: true)
        } else {
            navigationController?.pushViewController(viewController, animated: true)
        }
    }
    
    func showPlayer() {
        if UIDevice.isPad() {
            NotificationCenter.postNotificationToMainThread(name: ISMSNotification_ShowPlayer)
        } else {
            let controller = PlayerViewController()
            controller.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(controller, animated: true)
        }
    }
}
