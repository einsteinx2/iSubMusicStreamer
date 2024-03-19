//
//  AutoScrollingLabel.swift
//  iSub
//
//  Created by Benjamin Baron on 11/11/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

private let labelGap = 25.0

@objc final class AutoScrollingLabel: UIView {
    private let centerIfPossible: Bool
    private let scrollView = UIScrollView()
    private let label1 = UILabel() // actual basic label
    private let label2 = UILabel() // secondary copy of the label, to the right of the first
    private let labelCentered = UILabel() // for when shorter labels are to be displayed centered
    private var animator: UIViewPropertyAnimator?

    private var observers = Set<NSObject>()

    @objc var autoScroll = true
    @objc var repeatScroll = true

    private var isScrolling = false

    @objc var font: UIFont? {
        get {
            label1.font
        }
        set {
            label1.font = newValue
            label2.font = newValue
            labelCentered.font = newValue
            if self.window != nil {
                stopScrolling()
                if autoScroll {
                    startScrolling()
                }
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
            labelCentered.textColor = newValue
        }
    }
    
    @objc var text: String? {
        get {
            label1.text
        }
        set {
            label1.text = newValue
            label2.text = newValue
            labelCentered.text = newValue
            setNeedsLayout()
            if self.window != nil {
                stopScrolling()
                if autoScroll {
                    Task {
                        try await Task.sleep(nanoseconds: 600_000_000)
                        startScrolling()
                    }
                }
            }
        }
    }
    
    init(centerIfPossible: Bool = false) { // if true, we will center the text if it's short enough
        self.centerIfPossible = centerIfPossible
        super.init(frame: .zero)

        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isUserInteractionEnabled = false
        scrollView.decelerationRate = .fast
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.width.equalToSuperview().priority(.required)
            make.leading.top.bottom.equalToSuperview().priority(.required)
        }
        
        let contentView = UIView()
        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.leading.trailing.top.bottom.equalTo(scrollView.contentLayoutGuide).priority(.required)
        }

        contentView.addSubview(label1)
        label1.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }

        label2.isHidden = true
        contentView.addSubview(label2)
        label2.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(label1.snp.trailing).offset(labelGap)
            make.trailing.equalToSuperview().offset(labelGap)
        }

        labelCentered.isHidden = true
        self.addSubview(labelCentered)
        labelCentered.snp.makeConstraints { make in
            make.leading.top.right.bottom.equalToSuperview()
        }
        labelCentered.textAlignment = .center

        var observer = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) {
            [unowned self] _ in stopScrolling()
        }
        observers.insert(observer as! NSObject)
        observer = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) {
            [unowned self] _ in if autoScroll { startScrolling() }
        }
        observers.insert(observer as! NSObject)
        observer = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) {
            [unowned self] _ in stopScrolling()
        }
        observers.insert(observer as! NSObject)
        observer = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) {
            [unowned self] _ in if autoScroll { startScrolling() }
        }
        observers.insert(observer as! NSObject)
        observer = NotificationCenter.default.addObserver(forName: .init("playlistAppearing"), object: nil, queue: nil) {
            [unowned self] _ in stopScrolling()
        }
        observers.insert(observer as! NSObject)
        observer = NotificationCenter.default.addObserver(forName: .init("playlistDisappearing"), object: nil, queue: nil) {
            [unowned self] _ in if autoScroll { startScrolling() }
        }
        observers.insert(observer as! NSObject)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unsupported")
    }
    
    deinit {
        stopScrolling()
        for observer in self.observers {
            NotificationCenter.default.removeObserver(observer)
        }
        self.observers.removeAll()
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        stopScrolling()
        if window != nil {
            if autoScroll {
                Task {
                    try await Task.sleep(nanoseconds: 800_000_000)
                    startScrolling()
                }
            }
        }
    }

    override func layoutSubviews() {
        // momentarily hide labels so no "jump" is visible to user
        label1.isHidden = true
        labelCentered.isHidden = true
        super.layoutSubviews()
        CATransaction.setCompletionBlock { [unowned self] in // wait for layout to actually finish
            if centerIfPossible {
                if label1.bounds.width <= self.bounds.width { // we won't be scrolling
                    label1.isHidden = true
                    labelCentered.isHidden = false
                } else {
                    label1.isHidden = false
                    labelCentered.isHidden = true
                }
            } else {
                label1.isHidden = false
                labelCentered.isHidden = true
            }
        }
    }

    private func createAnimator(delay: TimeInterval) {
        guard scrollView.frame.width > 0, label1.frame.width > 0, scrollView.frame.width < label1.frame.width else { return }
        
        // Stop any existing animation
        stopScrolling()
        
        // Unhide label2 for the animation
        label2.isHidden = false
        
        // Create the new animation
        let minDuration = 1.0
        var duration = TimeInterval((label1.frame.width * 2) - scrollView.frame.width) * 0.03
        duration = duration < minDuration ? minDuration : duration
        animator = UIViewPropertyAnimator(duration: duration, curve: .linear) { [unowned self] in
            // Animate to show the second label
            self.scrollView.contentOffset.x = self.label1.frame.width + CGFloat(labelGap)
        }
        animator?.addCompletion { [unowned self] position in
            // Reset scroll view before the next run
            stopScrolling()
            if self.repeatScroll {
                self.startScrolling(delay: delay)
            }
        }
        animator?.isInterruptible = true
        isScrolling = true
    }
    
    private func resetScrollView() {
        label2.isHidden = true
        scrollView.contentOffset = .zero
    }
    
    @objc func startScrolling(delay: TimeInterval = 2) {
        // Prevent iOS from killing the app for overusing the CPU in the background
        // NOTE: While the notification listeners stop the animation when the app enters
        //       the backgorund, whenever the song would change, it would kick off the
        //       animations again which would short-circuit and eat up CPU.
        //       This check prevents any animation while in the background.
        guard UIApplication.shared.applicationState == .active else { return }
        guard !isScrolling else { return }

        createAnimator(delay: delay)
        animator?.startAnimation(afterDelay: delay)
    }
    
    @objc func stopScrolling() {
        animator?.stopAnimation(true)
        animator = nil
        isScrolling = false
        resetScrollView()
    }
}
