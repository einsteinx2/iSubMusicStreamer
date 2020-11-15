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
    private let label1 = UILabel()
    private let label2 = UILabel()
    private var animator: UIViewPropertyAnimator?
    
    // Hack to use inside table header due to UITableView header AutoLayout weirdness
    @objc var isInsideTableHeader = false
    
    @objc var autoScroll = true
    @objc var repeatScroll = true
    
    @objc var font: UIFont? {
        get {
            label1.font
        }
        set {
            label1.font = newValue
            label2.font = newValue
            stopScrolling()
            updateLabelSize()
            if autoScroll {
                startScrolling()
            }
        }
    }
    
    @objc var textColor: UIColor? {
        get {
            label1.textColor
        }
        set {
            label1.textColor = newValue
            label2.textColor = newValue
        }
    }
    
    @objc var text: String? {
        get {
            label1.text
        }
        set {
            label1.text = newValue
            label2.text = newValue
            stopScrolling()
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
            make.leading.trailing.top.bottom.equalToSuperview()
        }
        
        // Must use an intermediary content view for autolayout to work correctly inside a scroll view
        let contentView = UIView()
        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.leading.trailing.top.bottom.equalToSuperview()
        }
        
        contentView.addSubview(label1)
        label1.snp.makeConstraints { make in
            make.centerY.equalTo(scrollView)
        }
        
        contentView.addSubview(label2)
        label2.snp.makeConstraints { make in
            make.centerY.equalTo(scrollView)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("unsupported")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        updateLabelSize()
        scrollView.layoutSubviews()

        if autoScroll {
            startScrolling()
        }
    }
    
    func updateLabelSize() {
        guard let text = text, let font = font, scrollView.frame.width > 0, !isInsideTableHeader else { return }

        let size = text.boundingRect(with: CGSize(width: 1000, height: self.frame.height),
                                     options: .usesLineFragmentOrigin,
                                     attributes: [NSAttributedString.Key.font: font],
                                     context: nil)
        label1.frame.size.width = size.width
        label2.frame.size.width = size.width
    }
    
    private func createAnimator(delay: TimeInterval) {
        guard scrollView.frame.width > 0, scrollView.frame.width < label1.frame.width else { return }
        
        // Set initial positions
        label1.frame.origin.x = 0
        label2.frame.origin.x = label1.frame.width + 50//scrollView.frame.width
        
        // Stop any existing animation
        stopScrolling()
        
        // Create the new animation
        let startTime = Date()
        let minDuration = 1.0
        var duration = TimeInterval((label1.frame.width * 2) - scrollView.frame.width) * 0.03
        duration = duration < minDuration ? minDuration : duration
        animator = UIViewPropertyAnimator(duration: duration, curve: .linear) { [unowned self] in
            // Animate to show the second label
            let x = self.label1.frame.width + 50
            self.scrollView.contentOffset = CGPoint(x: x, y: self.scrollView.contentOffset.y)//0)
        }
        animator?.addCompletion { [unowned self] position in
            // Hack due to UIKit bug that causes the completion block to fire instantly
            // if animation starts before the view is fully displayed like in a table cell
            guard Date().timeIntervalSince(startTime) > (delay + duration) * 0.9 else {
                // Instantly reset the view position and restart the animation
                self.scrollView.contentOffset = CGPoint(x: 0, y: self.scrollView.contentOffset.y)//CGPoint.zero
                self.animator = nil;
                self.startScrolling(delay: delay)
                return
            }
            
            // Reset scroll view before the next run
            self.scrollView.contentOffset = CGPoint(x: 0, y: self.scrollView.contentOffset.y)
            self.animator = nil;
            if self.repeatScroll {
                self.startScrolling(delay: delay * 5)
            }
        }
        animator?.isInterruptible = true
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
    
    deinit {
        stopScrolling()
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if self.window == nil {
            self.stopScrolling()
        }
    }
}
