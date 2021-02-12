//
//  UIViewController+PushCustom.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit

extension UIViewController {
    func pushViewControllerCustom(_ viewController: UIViewController) {
        if let self = self as? UINavigationController {
            self.pushViewController(viewController, animated: true)
        } else {
            navigationController?.pushViewController(viewController, animated: true)
        }
    }
}
