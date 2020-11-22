//
//  PadMenuTableCell.swift
//  iSub
//
//  Created by Benjamin Baron on 11/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit

class PadMenuTableCell: UITableViewCell {
    static let reuseId = "PadMenuTableCell"
    
    private let indicatorLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        clipsToBounds = true
        
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .black
        
        backgroundColor = .clear
        backgroundView = UIView()
        
        textLabel?.font = .boldSystemFont(ofSize: UIFont.systemFontSize)
        textLabel?.snp.makeConstraints { make in
            make.width.equalToSuperview().offset(-75)
            make.height.top.equalToSuperview()
            make.leading.equalToSuperview().offset(75)
        }
        
        imageView?.alpha = 0.6
        imageView?.contentMode = .center
        imageView?.snp.makeConstraints { make in
            make.width.equalTo(70)
            make.height.leading.top.equalToSuperview()
        }
        
        indicatorLabel.text = "•"
        indicatorLabel.textColor = UIColor(white: 1, alpha: 0.25)
        indicatorLabel.font = .boldSystemFont(ofSize: 60)
        indicatorLabel.isHidden = true
        addSubview(indicatorLabel)
        indicatorLabel.snp.makeConstraints { make in
            make.width.equalTo(40)
            make.height.equalTo(36)
            make.top.equalToSuperview()
            make.leading.equalToSuperview().offset(-14)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selected {
            textLabel?.textColor = .white
        } else {
            textLabel?.textColor = UIColor(white: 188.0/255.0, alpha: 1)
        }
        indicatorLabel.isHidden = !selected
    }
}
