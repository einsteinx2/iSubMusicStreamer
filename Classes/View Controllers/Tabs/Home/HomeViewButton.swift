//
//  HomeViewButton.swift
//  iSub
//
//  Created by Benjamin Baron on 2/4/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit

final class HomeViewButton: UIView {
    private let button = UIButton(type: .custom)
    private let label = UILabel()
    
    init(icon: UIImage?, title: String, actionHandler: (() -> ())? = nil) {
        super.init(frame: CGRect.zero)
                
        button.setImage(icon, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.setImage(icon, for: .normal)
        if let actionHandler = actionHandler {
            button.addClosure(for: .touchUpInside, closure: actionHandler)
        }
        addSubview(button)
        button.snp.makeConstraints { make in
            make.width.height.equalTo(70)
            make.top.centerX.equalToSuperview()
        }
        
        label.font = .boldSystemFont(ofSize: 20)
        label.numberOfLines = 2
        label.text = title;
        label.textAlignment = .center
        label.textColor = .label
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    func setIcon(image: UIImage?) {
        button.setImage(image, for: .normal)
    }
    
    func setIconTint(color: UIColor) {
        button.tintColor = color
    }
    
    func setTitle(title: String) {
        button.setTitle(title, for: .normal)
    }
    
    func setAction(handler: @escaping () -> ()) {
        button.addClosure(for: .touchUpInside, closure: handler)
    }
    
    func hideLabel() {
        label.removeFromSuperview()
        invalidateIntrinsicContentSize()
    }
    
    func showLabel() {
        addSubview(label)
        label.snp.remakeConstraints { make in
            make.top.equalTo(button.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        invalidateIntrinsicContentSize()
    }
    
    override var intrinsicContentSize: CGSize {
        if label.superview != nil {
            return CGSize(width: 120, height: 120)
        } else {
            return CGSize(width: 120, height: 70)
        }
    }
}
