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

            // ProgressHUD presents in the key window; in a headless launch (e.g.
            // CarPlay-only, no phone scene) there is none, so skip entirely
            guard await MainActor.run(body: { UIApplication.keyWindow != nil }) else { return }

            let text = message ?? defaultMessage
            let secondaryText = closeHandler == nil ? nil : "tap to cancel"
            await ProgressHUD.animate(text, secondaryText: secondaryText, type: .activityIndicator, interaction: false, tapHandler: closeHandler)

            // hide() may have raced the animate-in: when its cancel lands after the
            // guard above, its dismiss is processed before the HUD ever shows and is
            // dropped, leaving a stray fullscreen HUD that blocks all interaction.
            // By this point the show work is enqueued on main, so a dismiss enqueued
            // now is guaranteed to run after it. Skip the re-dismiss when a NEWER
            // show has already replaced this task — its HUD must stay up (its own
            // lifecycle handles hiding it).
            if Task.isCancelled, HUD.task == nil {
                await ProgressHUD.dismiss()
            }
        }
    }
    
    static func hide() {
        task?.cancel()
        task = nil
        ProgressHUD.dismiss()
    }

    // Banner variant with the same no-key-window guard, for call sites that can
    // fire from headless (CarPlay-only) launches where ProgressHUD has no window
    // to present in. Pure UI call sites (context menus, swipe actions) can keep
    // using ProgressHUD.banner directly.
    static func banner(_ text: String?, _ subtitle: String?) {
        DispatchQueue.mainSyncSafe {
            guard UIApplication.keyWindow != nil else { return }
            ProgressHUD.banner(text, subtitle)
        }
    }
}
