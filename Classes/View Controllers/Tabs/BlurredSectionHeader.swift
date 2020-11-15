//
//  BlurredSectionHeader.swift
//  iSub
//
//  Created by Benjamin Baron on 11/14/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

@objc class BlurredSectionHeader: UITableViewHeaderFooterView {
    @objc static let reuseId = "BlurredSectionHeader"
    
    // TODO: Fix looks gray against black background
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    private let label = UILabel()
    
    @objc var text: String? {
        get { return label.text }
        set { label.text = newValue }
    }
    
    @objc override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        // In order for the blur to work correctly it must be the background view
        backgroundView = blurView
        
        label.font = .boldSystemFont(ofSize: 42)
        label.textColor = .label
        contentView.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalTo(contentView).offset(10)
            make.trailing.top.bottom.equalTo(contentView)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
}
