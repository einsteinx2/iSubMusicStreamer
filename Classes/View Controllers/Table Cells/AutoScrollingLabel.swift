//
//  AutoScrollingLabel.swift
//  iSub
//
//  Created by Benjamin Baron on 11/11/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

@objc class AutoScrollingLabel: UIView {
    private let scrollView = UIScrollView()
    private let label = UILabel()
    private var animator: UIViewPropertyAnimator?
    
    @objc var autoScroll = true
    @objc var repeatScroll = true
    
    @objc var font: UIFont? {
        get { label.font }
        set { label.font = newValue }
    }
    
    @objc var textColor: UIColor? {
        get { label.textColor }
        set { label.textColor = newValue }
    }
    
    @objc var text: String? {
        get { label.text }
        set {
            label.text = newValue
            updateLabelSize()
            if autoScroll {
                startScrolling()
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isUserInteractionEnabled = false
        scrollView.decelerationRate = .fast
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.left.equalTo(self)
            make.right.equalTo(self)
            make.top.equalTo(self)
            make.bottom.equalTo(self)
        }
        
        scrollView.addSubview(label)
        label.snp.makeConstraints { make in
            make.left.equalTo(scrollView)
            make.centerY.equalTo(scrollView)
            make.bottom.equalTo(scrollView)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("unsupported")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        scrollView.layoutSubviews()
        updateLabelSize()
        
        if (autoScroll) {
            startScrolling()
        }
    }
    
    private func updateLabelSize() {
        guard let text = text, let font = font else { return }
        
        let size = text.boundingRect(with: CGSize(width: 1000, height: self.frame.height),
                                     options: .usesLineFragmentOrigin,
                                     attributes: [NSAttributedString.Key.font: font],
                                     context: nil)
        label.frame.size.width = size.width
    }
    
    private func createAnimator(delay: TimeInterval) {
        guard scrollView.frame.width > 0, scrollView.frame.width < label.frame.width else { return }
        
        // Stop any existing animation
        stopScrolling()
        
        // Create the new animation
        let startTime = Date()
        let minDuration = 1.0
        var duration = TimeInterval(label.frame.width - scrollView.frame.width) * 0.03
        duration = duration < minDuration ? minDuration : duration
        animator = UIViewPropertyAnimator.runningPropertyAnimator(withDuration: duration, delay: delay, options: .curveLinear, animations: {
            let x = self.label.frame.width - self.scrollView.frame.width + 20
            self.scrollView.contentOffset = CGPoint(x: x, y: 0)
        }, completion: { position in
            // Hack due to UIKit bug that causes the completion block to fire instantly
            // if animation starts before the view is fully displayed like in a table cell
            guard Date().timeIntervalSince(startTime) > (delay + duration) * 0.9 else {
                // Instantly reset the view position and restart the animation
                self.scrollView.contentOffset = CGPoint.zero
                self.animator = nil;
                self.startScrolling(delay: delay)
                return
            }
            
            // Scroll back when finished
            self.animator = UIViewPropertyAnimator.runningPropertyAnimator(withDuration: duration, delay: 0.75, options: .curveLinear, animations: {
                self.scrollView.contentOffset = CGPoint.zero
            }, completion: { _ in
                self.animator = nil;
                if (self.repeatScroll) {
                    self.startScrolling(delay: delay)
                }
            });
        })
    }
    
    @objc func startScrolling(delay: TimeInterval = 2.5) {
        createAnimator(delay: delay)
        animator?.startAnimation(afterDelay: delay)
    }
    
    @objc func stopScrolling() {
        animator?.stopAnimation(true)
        animator = nil
        self.scrollView.contentOffset = CGPoint.zero
    }
}
