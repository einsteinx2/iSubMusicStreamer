//
//  RefreshControl.swift
//  iSub
//
//  Created by Benjamin Baron on 11/14/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit

@objc class RefreshControl: UIRefreshControl {
    @objc init(handler: @escaping () -> ()) {
        super.init()
        let attributes = [NSAttributedString.Key.foregroundColor: UIColor.label, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)]
        attributedTitle = NSAttributedString(string: "Pull to refresh...", attributes: attributes)
        addClosure(for: .valueChanged, closure: handler)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
}
