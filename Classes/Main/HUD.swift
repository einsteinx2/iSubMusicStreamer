//
//  HUD.swift
//  iSub
//
//  Created by Benjamin Baron on 1/19/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

struct HUD {
    private static let defaultGraceTime = 0.3
    private static let defaultMessage = "Loading"
    private static let defaultCancelMessage = "tap to cancel"
    
    fileprivate static var hud: MBProgressHUD?
    private static let hudDelegate = HUDDelegate()
    
    // TODO: Update this to support multiple scenes
    private static var window: UIWindow? { UIApplication.keyWindow }
    
    @discardableResult
    static func show(message: String? = nil, closeHandler: (() -> Void)? = nil) -> Bool {
        guard hud == nil, let window = window else { return false }
        DispatchQueue.main.async {
            let hud = MBProgressHUD(view: window)
            hud.delegate = hudDelegate
            hud.graceTime = defaultGraceTime
            hud.label.text = message ?? defaultMessage
            
            if let closeHandler = closeHandler {
                // TODO: verify on iPad
                hud.detailsLabel.text = defaultCancelMessage
                hud.isUserInteractionEnabled = true
                let cancelButton = UIButton(type: .custom)
                cancelButton.addClosure(for: .touchUpInside, closure: closeHandler)
                hud.bezelView.addSubview(cancelButton)
                cancelButton.snp.makeConstraints { make in
                    make.leading.trailing.top.bottom.equalToSuperview()
                }
            }
            
            window.addSubview(hud)
            hud.show(animated: true)
            self.hud = hud
        }
        return true
    }
    
    @discardableResult
    static func hide() -> Bool {
        guard let hud = hud else { return false }
        DispatchQueue.main.async {
            hud.hide(animated: true)
        }
        return true
    }
}

private class HUDDelegate: MBProgressHUDDelegate {
    func hudWasHidden(_ hud: MBProgressHUD) {
        hud.removeFromSuperview()
        HUD.hud = nil
    }
}
