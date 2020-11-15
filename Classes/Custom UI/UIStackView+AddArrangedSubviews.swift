//
//  UIStackView+AddArrangedSubviews.swift
//  iSub
//
//  Created by Benjamin Baron on 11/15/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit

extension UIStackView {
    func addArrangedSubviews(_ views: [UIView]) {
        for view in views {
            addArrangedSubview(view)
        }
    }
}
