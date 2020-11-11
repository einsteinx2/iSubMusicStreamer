//
//  UniversalTableViewCell.swift
//  iSub
//
//  Created by Benjamin Baron on 11/11/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

@objc
public class UniversalTableViewCell : UITableViewCell {
    @objc static let reuseId = "UniversalTableViewCell"
    
    let nameLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        nameLabel.textColor = .label
        nameLabel.font = .boldSystemFont(ofSize: 24)
        addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.left.equalTo(self)
            $0.right.equalTo(self)
            $0.top.equalTo(self)
            $0.bottom.equalTo(self)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    @objc func updateCell(withArtist artist: Artist) {
        nameLabel.text = artist.name
    }
}
