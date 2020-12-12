//
//  BlurredSectionHeader.swift
//  iSub
//
//  Created by Benjamin Baron on 11/14/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

@objc final class BlurredSectionHeader: UITableViewHeaderFooterView {
    @objc static let reuseId = "BlurredSectionHeader"
    
    // TODO: Fix looks gray against black background
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let label = UILabel()
    
    @objc var text: String? {
        get { return label.text }
        set { label.text = newValue }
    }
    
    @objc override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        // In order for the blur to work correctly it must be the background view
        backgroundView = blurView
        
        label.font = .boldSystemFont(ofSize: UIDevice.isSmall() ? 36 : 42)
        label.textColor = .label
        contentView.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.trailing.top.bottom.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
}
