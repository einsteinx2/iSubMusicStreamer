//
//  HUD.swift
//  iSub
//
//  Created by Benjamin Baron on 1/19/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

@objc class HUD: NSObject {
    private static let defaultGraceTime = 0.5
    private static let defaultMessage = "Loading"
    private static let defaultCancelMessage = "tap to cancel"
    
    fileprivate static var hud: MBProgressHUD?
    private static let hudDelegate = HUDDelegate()
    
    // TODO: Update this to support multiple scenes
    private static var window: UIWindow? { UIApplication.keyWindow }
    
    @objc @discardableResult
    static func show() -> Bool {
        return show(message: nil)
    }
    
    @objc @discardableResult
    static func show(closeHandler: @escaping () -> Void) -> Bool {
        return show(message: nil, closeHandler: closeHandler)
    }
    
    @objc @discardableResult
    static func show(message: String?) -> Bool {
        guard hud == nil, let window = window else { return false }
        
        DispatchQueue.main.async {
            let hud = MBProgressHUD(view: window)
            hud.delegate = hudDelegate
            hud.graceTime = defaultGraceTime
            hud.label.text = message ?? defaultMessage
            window.addSubview(hud)
            hud.show(animated: true)
            self.hud = hud
        }
        return true
    }
    
    @objc @discardableResult
    static func show(message: String?, closeHandler: @escaping () -> Void) -> Bool {
        guard hud == nil, let window = window else { return false }
        
        DispatchQueue.main.async {
            let hud = MBProgressHUD(view: window)
            hud.delegate = hudDelegate
            hud.graceTime = defaultGraceTime
            hud.label.text = message ?? defaultMessage
            hud.detailsLabel.text = defaultCancelMessage
            
            // TODO: verify on iPad
            hud.isUserInteractionEnabled = true
            let cancelButton = UIButton(type: .custom)
            cancelButton.addClosure(for: .touchUpInside, closure: closeHandler)
            hud.bezelView.addSubview(cancelButton)
            cancelButton.snp.makeConstraints { make in
                make.leading.trailing.top.bottom.equalToSuperview()
            }
            
            window.addSubview(hud)
            hud.show(animated: true)
            self.hud = hud
        }
        return true
    }
    
    @objc @discardableResult
    static func hide() -> Bool {
        guard let hud = hud else { return false }
        
        DispatchQueue.main.async {
            hud.hide(animated: true)
        }
        return true
    }
}

private class HUDDelegate: NSObject, MBProgressHUDDelegate {
    func hudWasHidden(_ hud: MBProgressHUD) {
        hud.removeFromSuperview()
        HUD.hud = nil
    }
}
