//
//  HUD.swift
//  iSub
//
//  Created by Benjamin Baron on 1/19/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit
import ProgressHUD

struct HUD {
    private static let defaultGraceTime: UInt64 = 300_000_000 // 0.3 seconds
    private static let defaultMessage = "Loading"
    private static let defaultCancelMessage = "tap to cancel"
    
    private static var task: Task<Void, Never>?
    
    static func show(message: String? = nil, closeHandler: (() -> Void)? = nil) {
        task?.cancel()
        
        task = Task {
            try? await Task.sleep(nanoseconds: defaultGraceTime)
            guard !Task.isCancelled else { return }
            
            let text = message ?? defaultMessage
            let secondaryText = closeHandler == nil ? nil : "tap to cancel"
            await ProgressHUD.animate(text, secondaryText: secondaryText, type: .activityIndicator, interaction: false, tapHandler: closeHandler)
        }
    }
    
    static func hide() {
        task?.cancel()
        task = nil
        ProgressHUD.dismiss()
    }
}

/*import UIKit
import SnapKit
import ProgressHUD

struct HUD {
//    private static let defaultGraceTime = 0.3
    private static let defaultMessage = "Loading"
    private static let defaultCancelMessage = "tap to cancel"
    
    private static var cancelButton: UIButton?
    
//    fileprivate static var hud: MBProgressHUD?
//    private static let hudDelegate = HUDDelegate()
    
    // TODO: Update this to support multiple scenes
//    private static var window: UIWindow? { UIApplication.keyWindow }
   
    static func show(message: String? = nil, closeHandler: (() -> Void)? = nil) {
        ProgressHUD.animate(message ?? defaultMessage, .activityIndicator, interaction: false)
        
        if let closeHandler = closeHandler {
            // TODO: verify on iPad
            DispatchQueue.main.async {
                self.cancelButton?.removeFromSuperview()
                self.cancelButton = UIButton(type: .custom)
                if let cancelButton = self.cancelButton {
                    cancelButton.addClosure(for: .touchUpInside, closure: closeHandler)
                    UIApplication.shared.windows.first?.addSubview(cancelButton)
                    cancelButton.snp.makeConstraints { make in
                        make.leading.trailing.top.bottom.equalToSuperview()
                    }
                }
            }
       }
    }
    
//    @discardableResult
//    static func show(message: String? = nil, closeHandler: (() -> Void)? = nil) -> Bool {
//        guard hud == nil, let window = window else { return false }
////        DispatchQueue.main.async {
//        Task {
//            await MainActor.run {
//                let hud = MBProgressHUD(view: window)
//                hud.delegate = hudDelegate
//                hud.graceTime = defaultGraceTime
//                hud.label.text = message ?? defaultMessage
//                
//                if let closeHandler = closeHandler {
//                    // TODO: verify on iPad
//                    hud.detailsLabel.text = defaultCancelMessage
//                    hud.isUserInteractionEnabled = true
//                    let cancelButton = UIButton(type: .custom)
//                    cancelButton.addClosure(for: .touchUpInside, closure: closeHandler)
//                    hud.bezelView.addSubview(cancelButton)
//                    cancelButton.snp.makeConstraints { make in
//                        make.leading.trailing.top.bottom.equalToSuperview()
//                    }
//                }
//                
//                window.addSubview(hud)
//                hud.show(animated: true)
//                self.hud = hud
//            }
//        }
//        return true
//    }
    
//    @discardableResult
//    static func hide() -> Bool {
//        guard let hud = hud else { return false }
////        DispatchQueue.main.async {
//        Task {
//            await MainActor.run {
//                hud.hide(animated: true)
//            }
//        }
//        return true
//    }
    
    static func hide() {
        ProgressHUD.dismiss()
        self.cancelButton?.removeFromSuperview()
        self.cancelButton = nil
    }
}

//private class HUDDelegate: MBProgressHUDDelegate {
//    func hudWasHidden(_ hud: MBProgressHUD) {
////        DispatchQueue.main.async {
//        Task {
////            try? await Task.sleep(nanoseconds: 2000000000)
//            await MainActor.run {
//                hud.removeFromSuperview()
//                HUD.hud = nil
//            }
//        }
//    }
//}
*/
