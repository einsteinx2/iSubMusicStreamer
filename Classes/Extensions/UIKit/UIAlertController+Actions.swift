//
//  UIAlertController+Actions.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit

extension UIAlertController {
    func addAction(title: String?, style: UIAlertAction.Style, handler: ((UIAlertAction) -> Void)? = nil) {
        addAction(UIAlertAction(title: title, style: style, handler: handler))
    }
    
    func addCancelAction(title: String = "Cancel", handler: ((UIAlertAction) -> Void)? = nil) {
        addAction(UIAlertAction(title: title, style: .cancel, handler: handler))
    }
    
    func addOKAction(title: String = "OK", handler: ((UIAlertAction) -> Void)? = nil) {
        addAction(UIAlertAction(title: title, style: .cancel, handler: handler))
    }
}
