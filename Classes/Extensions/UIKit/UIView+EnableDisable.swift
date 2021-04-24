//
//  UIView+EnableDisable.swift
//  iSub
//
//  Created by Benjamin Baron on 4/24/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit

extension UIView {
    private struct AssociatedKeys {
        static var originalAlpha: UInt8 = 0
    }
    
    func enable(useOriginalAlpha: Bool = true) {
        var originalAlpha: CGFloat = 1.0
        if useOriginalAlpha, let originalAlphaValue = objc_getAssociatedObject(self, &AssociatedKeys.originalAlpha) as? CGFloat {
            originalAlpha = originalAlphaValue
        }        
        isUserInteractionEnabled = true
        alpha = originalAlpha
    }
    
    func disable(dimmedAlpha: CGFloat = 0.5) {
        objc_setAssociatedObject(self, &AssociatedKeys.originalAlpha, alpha, .OBJC_ASSOCIATION_RETAIN)
        isUserInteractionEnabled = false
        alpha = dimmedAlpha
    }
}
