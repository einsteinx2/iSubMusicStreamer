//
//  UIApplication+Helper.swift
//  iSub
//
//  Created by Benjamin Baron on 1/19/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit

extension UIApplication {
    static var orientation: UIInterfaceOrientation {
        UIApplication.shared.windows.first?.windowScene?.interfaceOrientation ?? .portrait
    }
    
    static var keyWindow: UIWindow? {
        UIApplication.shared.windows.first { $0.isKeyWindow }
    }
    
    static var statusBarHeight: CGFloat {
        keyWindow?.windowScene?.statusBarManager?.statusBarFrame.size.height ?? 0
    }
}
