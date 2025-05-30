//
//  RefreshControl.swift
//  iSub
//
//  Created by Benjamin Baron on 11/14/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit

fileprivate let defaultTitleAttributes = [NSAttributedString.Key.foregroundColor: UIColor.label,
                                          NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)]
fileprivate let defaultAttributedTitle = NSAttributedString(string: "Pull to refresh...", attributes: defaultTitleAttributes)

final class RefreshControl: UIRefreshControl {
    init(handler: @escaping () -> ()) {
        super.init()
        attributedTitle = defaultAttributedTitle
        addClosure(for: .valueChanged, closure: handler)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    override func endRefreshing() {
        // Fix for annoying bug where the title flickers in over the table cells after refresh ends if the table header is short
        // NOTE: I tried a bunch of solutions and removing the attributed title before calling endRefreshing is the only one that worked, at least as of 2025-05-30
        // NOTE: This is explicity a space rather than empty string and using the same attributes as the real title or the table will move up slightly which looks bad
        attributedTitle = NSAttributedString(string: " ", attributes: defaultTitleAttributes)
        super.endRefreshing()
        
        // NOTE: If the title is set back too quickly, it will still flicker. I found 0.5 was too short, so went with 1.0
        DispatchQueue.main.async(after: 1.0) { [weak self] in
            guard let self else { return }
            self.attributedTitle = defaultAttributedTitle
        }
    }
}
