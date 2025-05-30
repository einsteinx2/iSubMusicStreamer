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
