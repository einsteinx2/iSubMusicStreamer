//
//  SlidingNotification.swift
//  iSub
//
//  Created by Benjamin Baron on 12/11/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

// TODO: Add more display modes, currently always uses window mode
//private enum DisplayMode {
//    case window
//    case navigationBar
//    case tabBar
//}

private let animationDuration = 0.2
private let labelInset: Float = 12.5

@objc final class SlidingNotification: UIView {
    static let defaultDuration = 2.0
    
    static var throttlingEnabled = true
    static var activeMessages = Set<String>()
    
    private var isAnimating = false
    private var isShowing = false
    
    private var blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private var messageLabel = UILabel()
    private let message: String
    
    private init(message: String) {
        self.message = message
        super.init(frame: .zero)
        
        // Always use dark mode to better match navigation bar color
        overrideUserInterfaceStyle = .dark
        
        addSubview(blurView)
        blurView.snp.makeConstraints { make in
            make.leading.trailing.top.bottom.equalToSuperview()
        }
        
        messageLabel.numberOfLines = 0
        blurView.contentView.addSubview(messageLabel)
        messageLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(labelInset)
            make.trailing.bottom.equalToSuperview().offset(-labelInset)
        }
        
        // Add line spacing, so need to use an attributed string
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = 2
        let attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16),
                          NSAttributedString.Key.paragraphStyle: paragraphStyle]
        messageLabel.attributedText = NSAttributedString(string: message, attributes: attributes)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    private func show(duration: TimeInterval = defaultDuration) {
        guard let superview = superview, !isAnimating && !isShowing else { return }
        
        isAnimating = true
        Self.activeMessages.insert(message)

        snp.makeConstraints { make in
            make.bottom.equalTo(superview.snp.top)
            make.leading.trailing.equalToSuperview()
        }
        messageLabel.snp.updateConstraints { make in
            make.top.equalToSuperview().offset(Float(UIApplication.statusBarHeight()) + labelInset)
        }
        messageLabel.sizeToFit()
        superview.layoutIfNeeded()
        
        UIView.animate(withDuration: animationDuration) {
            self.snp.updateConstraints { make in
                make.bottom.equalTo(superview.snp.top).offset(self.frame.height)
            }
            superview.layoutIfNeeded()
        } completion: { _ in
            self.isShowing = true
            self.isAnimating = false
            
            if duration > 0 {
                self.perform(#selector(self.hide), with: nil, afterDelay: duration)
            }
        }
    }
    
    @objc private func hide() {
        guard let superview = superview, !isAnimating && isShowing else { return }
        
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hide), object: nil)
        
        UIView.animate(withDuration: animationDuration) {
            self.snp.updateConstraints { make in
                make.bottom.equalTo(superview.snp.top)
            }
            superview.layoutIfNeeded()
        } completion: { _ in
            self.removeFromSuperview()
            self.isShowing = false
            self.isAnimating = false
            Self.activeMessages.remove(self.message)
        }
    }
    
    @objc static func showOnMainWindow(message: String) {
        showOnMainWindow(message: message, duration: defaultDuration)
    }
    
    @objc static func showOnMainWindow(message: String, duration: TimeInterval) {
        guard !Self.activeMessages.contains(message) else { return }
        
        let slidingNotification = Self(message: message)
        UIApplication.keyWindow()?.addSubview(slidingNotification)
        slidingNotification.show(duration: duration)
    }
}
