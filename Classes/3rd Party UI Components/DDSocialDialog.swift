// Ported to Swift in 2025 by Ben Baron

//
//  DDSocialDialog.m
//
//  Created by digdog on 6/6/10.
//  Copyright 2010 Ching-Lan 'digdog' HUANG and digdog software. All rights reserved.
//  http://digdog.tumblr.com
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
//  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
//  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

/*
 * Copyright 2009 Facebook
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import UIKit
import CocoaLumberjackSwift

// MARK: Constants

private let kDDSocialDialogBorderWidth: CGFloat = 10
private let kDDSocialDialogTransitionDuration: TimeInterval = 0.3
private let kDDSocialDialogTitleMarginX: CGFloat = 8.0
private let kDDSocialDialogTitleMarginY: CGFloat = 4.0
private let kDDSocialDialogPadding: CGFloat = 10

// MARK: Enums

enum DDSocialDialogTheme {
    case twitter
    case plurk
    case iSub
}

// MARK: Protocols

protocol DDSocialDialogDelegate: AnyObject {
    func socialDialogDidCancel(_ socialDialog: DDSocialDialog)
}

// MARK: DDSocialDialog Class

class DDSocialDialog: UIView {

    // MARK: Properties

    let theme: DDSocialDialogTheme
    let titleLabel = UILabel(frame: .zero)
    var contentView = UIView(frame: .zero)
    weak var dialogDelegate: DDSocialDialogDelegate?

    private let closeButton = UIButton(type: .custom)
    private var touchInterceptingControl = UIControl(frame: UIScreen.main.bounds)
    private var defaultFrameSize: CGSize
    private var currentInterfaceOrientation: UIInterfaceOrientation = .unknown
    private var showingKeyboard: Bool = false

    // MARK: Initialization

    init(frame: CGRect, theme: DDSocialDialogTheme) {
        self.defaultFrameSize = frame.size
        self.theme = theme

        super.init(frame: .zero)

        backgroundColor = .clear
        autoresizesSubviews = true
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentMode = .redraw

        let closeButtonColor = UIColor(red: 167.0/255.0, green: 184.0/255.0, blue: 216.0/255.0, alpha: 1.0)
        closeButton.setTitle("X", for: .normal)
        closeButton.setTitleColor(closeButtonColor, for: .normal)
        closeButton.setTitleColor(.white, for: .highlighted)
        closeButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        closeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 12)
        closeButton.showsTouchWhenHighlighted = true
        closeButton.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        addSubview(closeButton)

        let titleLabelFontSize: CGFloat = (UIDevice.current.userInterfaceIdiom == .pad) ? 18 : 14
        titleLabel.text = String(describing: type(of: self))
        titleLabel.backgroundColor = .clear
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: titleLabelFontSize)
        titleLabel.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin]
        addSubview(titleLabel)

        contentView.backgroundColor = .white
        contentView.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin]
        contentView.contentMode = .redraw
        addSubview(contentView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Drawing

    override func draw(_ rect: CGRect) {
        let titleBackgroundColor: UIColor
        let titleStrokeColor: UIColor
        let blackStrokeColor: UIColor
        let borderColor: UIColor

        switch theme {
        case .plurk:
            titleBackgroundColor = UIColor(red: 0.953, green: 0.49, blue: 0.03, alpha: 1.0)
            titleStrokeColor = UIColor(red: 0.753, green: 0.341, blue: 0.145, alpha: 1.0)
            blackStrokeColor = UIColor(red: 0.753, green: 0.341, blue: 0.145, alpha: 1.0)
            borderColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.3)
        case .iSub:
            titleBackgroundColor = UIColor(white: 0.8, alpha: 1.0)
            titleStrokeColor = UIColor(white: 0.0, alpha: 1.0)
            blackStrokeColor = UIColor(white: 0.0, alpha: 1.0)
            borderColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.8)
        default: // .twitter theme
            titleBackgroundColor = UIColor(red: 0.557, green: 0.757, blue: 0.855, alpha: 1.0)
            titleStrokeColor = UIColor(red: 0.233, green: 0.367, blue: 0.5, alpha: 1.0)
            blackStrokeColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
            borderColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.3)
        }

        let grayRect = rect.offsetBy(dx: -0.5, dy: -0.5)
        drawRoundedRect(in: grayRect, fill: borderColor.cgColor, radius: 10)

        let headerRect = CGRect(x: rect.origin.x + kDDSocialDialogBorderWidth,
                                y: rect.origin.y + kDDSocialDialogBorderWidth,
                                width: rect.size.width - kDDSocialDialogBorderWidth * 2,
                                height: titleLabel.frame.size.height).integral
        drawRoundedRect(in: headerRect, fill: titleBackgroundColor.cgColor, radius: 0)
        strokeLines(for: headerRect, stroke: titleStrokeColor.cgColor)

        let contentDrawRect = CGRect(x: rect.origin.x + kDDSocialDialogBorderWidth,
                                 y: headerRect.origin.y + headerRect.size.height,
                                 width: rect.size.width - kDDSocialDialogBorderWidth * 2,
                                 height: contentView.frame.size.height + 1).integral
        strokeLines(for: contentDrawRect, stroke: blackStrokeColor.cgColor)
    }

    private func addRoundedRectToPath(context: CGContext, rect: CGRect, radius: CGFloat) {
        context.beginPath()
        context.saveGState()

        if radius == 0 {
            context.translateBy(x: rect.minX, y: rect.minY)
            context.addRect(rect)
        } else {
            let adjustedRect = rect.insetBy(dx: 0.5, dy: 0.5).offsetBy(dx: 0.5, dy: 0.5)
            context.translateBy(x: adjustedRect.minX - 0.5, y: adjustedRect.minY - 0.5)
            context.scaleBy(x: radius, y: radius)
            let fw = adjustedRect.width / radius
            let fh = adjustedRect.height / radius

            context.move(to: CGPoint(x: fw, y: fh / 2))
            context.addArc(tangent1End: CGPoint(x: fw, y: fh), tangent2End: CGPoint(x: fw / 2, y: fh), radius: 1)
            context.addArc(tangent1End: CGPoint(x: 0, y: fh), tangent2End: CGPoint(x: 0, y: fh / 2), radius: 1)
            context.addArc(tangent1End: CGPoint(x: 0, y: 0), tangent2End: CGPoint(x: fw / 2, y: 0), radius: 1)
            context.addArc(tangent1End: CGPoint(x: fw, y: 0), tangent2End: CGPoint(x: fw, y: fh / 2), radius: 1)
        }

        context.closePath()
        context.restoreGState()
    }

    private func drawRoundedRect(in rect: CGRect, fill fillColor: CGColor?, radius: CGFloat) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        if let fillColor {
            context.saveGState()
            context.setFillColor(fillColor)
            if radius > 0 {
                addRoundedRectToPath(context: context, rect: rect, radius: radius)
                context.fillPath()
            } else {
                context.fill(rect)
            }
            context.restoreGState()
        }
    }

    private func strokeLines(for rect: CGRect, stroke strokeColor: CGColor) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.saveGState()
        context.setStrokeColor(strokeColor)
        context.setLineWidth(1.0)

        var points: [CGPoint] = [CGPoint(x: rect.origin.x + 0.5, y: rect.origin.y - 0.5),
                                 CGPoint(x: rect.origin.x + rect.size.width, y: rect.origin.y - 0.5)]
        context.strokeLineSegments(between: points)

        points = [CGPoint(x: rect.origin.x + 0.5, y: rect.origin.y + rect.size.height - 0.5),
                  CGPoint(x: rect.origin.x + rect.size.width - 0.5, y: rect.origin.y + rect.size.height - 0.5)]
        context.strokeLineSegments(between: points)

        points = [CGPoint(x: rect.origin.x + rect.size.width - 0.5, y: rect.origin.y),
                  CGPoint(x: rect.origin.x + rect.size.width - 0.5, y: rect.origin.y + rect.size.height)]
        context.strokeLineSegments(between: points)

        points = [CGPoint(x: rect.origin.x + 0.5, y: rect.origin.y),
                  CGPoint(x: rect.origin.x + 0.5, y: rect.origin.y + rect.size.height)]
        context.strokeLineSegments(between: points)

        context.restoreGState()
    }

    // MARK: Public Methods

    func show() {
        sizeToFitOrientation(transform: false)

        let innerWidth = self.frame.size.width - (kDDSocialDialogBorderWidth + 1) * 2
        titleLabel.sizeToFit()
        closeButton.sizeToFit()

        titleLabel.frame = CGRect(
            x: kDDSocialDialogBorderWidth + kDDSocialDialogTitleMarginX,
            y: kDDSocialDialogBorderWidth,
            width: innerWidth - (titleLabel.frame.size.height + kDDSocialDialogTitleMarginX * 2),
            height: titleLabel.frame.size.height + kDDSocialDialogTitleMarginY * 2
        )

        closeButton.frame = CGRect(
            x: self.frame.size.width - (titleLabel.frame.size.height + kDDSocialDialogBorderWidth),
            y: kDDSocialDialogBorderWidth,
            width: titleLabel.frame.size.height,
            height: titleLabel.frame.size.height
        )
        
        contentView.frame = CGRect(
            x: kDDSocialDialogBorderWidth + 1,
            y: kDDSocialDialogBorderWidth + titleLabel.frame.size.height,
            width: innerWidth,
            height: self.frame.size.height - (titleLabel.frame.size.height + 1 + kDDSocialDialogBorderWidth * 2)
        )

        guard let window = UIApplication.keyWindow ?? UIApplication.shared.windows.first else {
            DDLogError("[DDSocialDialog] No window found to show dialog")
            return
        }
        
        touchInterceptingControl.isUserInteractionEnabled = true
        window.addSubview(touchInterceptingControl)
        
        window.addSubview(self)

        self.transform = currentTransformForOrientation().scaledBy(x: 0.1, y: 0.1)
        self.alpha = 0.0
        
        UIView.animate(withDuration: kDDSocialDialogTransitionDuration / 1.5, animations: {
            self.transform = self.currentTransformForOrientation().scaledBy(x: 1.1, y: 1.1)
            self.alpha = 1.0
        }) { finished in
            UIView.animate(withDuration: kDDSocialDialogTransitionDuration / 1.5) {
                self.transform = self.currentTransformForOrientation()
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(deviceOrientationDidChange(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(_:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc func cancel() {
        dialogDelegate?.socialDialogDidCancel(self)
        dismiss(animated: true)
    }

    func dismiss(animated: Bool) {
        if animated {
            UIView.animate(withDuration: kDDSocialDialogTransitionDuration / 1.5, animations: {
                self.transform = self.currentTransformForOrientation().scaledBy(x: 0.1, y: 0.1)
                self.alpha = 0.0
            }) { finished in
                self.postDismissCleanup()
            }
        } else {
            postDismissCleanup()
        }
    }

    private func postDismissCleanup() {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        removeFromSuperview()
        touchInterceptingControl.removeFromSuperview()
    }


    // MARK: Rotation Handling

    private func currentTransformForOrientation() -> CGAffineTransform {
        let orientation = UIApplication.orientation
        
        switch orientation {
        case .landscapeLeft:
            return CGAffineTransform(rotationAngle: .pi * 1.5) // Upside down landscape
        case .landscapeRight:
            return CGAffineTransform(rotationAngle: .pi / 2)
        case .portraitUpsideDown:
            return CGAffineTransform(rotationAngle: .pi) // Changed from -M_PI to M_PI as they are equivalent for 180 deg
        default: // .portrait or .unknown
            return .identity
        }
    }

    private func sizeToFitOrientation(transform: Bool) {
        if transform {
            self.transform = .identity
        }

        currentInterfaceOrientation = UIApplication.orientation

        let frameSize = defaultFrameSize
        self.frame = CGRect(x: kDDSocialDialogPadding,
                            y: kDDSocialDialogPadding,
                            width: frameSize.width - kDDSocialDialogPadding * 2,
                            height: frameSize.height - kDDSocialDialogPadding * 2)

        if !showingKeyboard {
            let screenSize = UIScreen.main.bounds.size
            self.center = CGPoint(x: ceil(screenSize.width / 2), y: ceil(screenSize.height / 2))
        }

        if transform {
            self.transform = currentTransformForOrientation()
        }
    }

    private func shouldRotateToOrientation(_ orientation: UIInterfaceOrientation) -> Bool {
        if orientation == self.currentInterfaceOrientation {
            return false
        } else {
            return orientation == .landscapeLeft ||
                   orientation == .landscapeRight ||
                   orientation == .portrait ||
                   orientation == .portraitUpsideDown
        }
    }

    // MARK: Notifications

    @objc private func deviceOrientationDidChange(_ notification: Notification) {
        let orientation = UIApplication.orientation
        
        if shouldRotateToOrientation(orientation) {
            if !showingKeyboard {
                if orientation.isLandscape {
                    contentView.frame = CGRect(
                        x: kDDSocialDialogBorderWidth + 1,
                        y: kDDSocialDialogBorderWidth + titleLabel.frame.size.height,
                        width: self.frame.size.width - (kDDSocialDialogBorderWidth + 1) * 2,
                        height: self.frame.size.height - (titleLabel.frame.size.height + 1 + kDDSocialDialogBorderWidth * 2)
                    )
                } else {
                    contentView.frame = CGRect(
                        x: kDDSocialDialogBorderWidth + 1,
                        y: kDDSocialDialogBorderWidth + titleLabel.frame.size.height,
                        width: self.frame.size.width - (kDDSocialDialogBorderWidth + 1) * 2,
                        height: self.frame.size.height - (titleLabel.frame.size.height + 1 + kDDSocialDialogBorderWidth * 2)
                    )
                }
            }

            let duration: TimeInterval = 0.3
            UIView.animate(withDuration: duration) {
                self.sizeToFitOrientation(transform: true)
            }
        }
    }

    @objc private func keyboardDidShow(_ notification: Notification) {
        let orientation = UIApplication.orientation
        
        if UIDevice.current.userInterfaceIdiom == .pad && orientation.isPortrait {
            // On the iPad the screen is large enough that we don't need to
            // resize the dialog to accommodate the keyboard popping up
            return
        }
        
        guard let keyboardFrameEnd = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            DDLogError("[DDSocialDialog] keyboardDidShow: Missing keyboard frame user info value")
            return
        }
        
        guard let keyboardAnimationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber else {
            DDLogError("[DDSocialDialog] keyboardDidShow: Missing keyboard animation diration user info value")
            return
        }
        
        let screenSize = UIScreen.main.bounds.size
        let keyboardSize = convert(keyboardFrameEnd.cgRectValue, to: nil).size
        
        let duration = keyboardAnimationDuration.doubleValue
        UIView.animate(withDuration: duration) {
            switch orientation {
            case .portrait:
                self.center = CGPoint(x: self.center.x, y: ceil((screenSize.height - keyboardSize.height) / 2) + 10.0)
            case .portraitUpsideDown:
                self.center = CGPoint(x: self.center.x, y: screenSize.height - (ceil((screenSize.height - keyboardSize.height) / 2) + 10.0))
            case .landscapeLeft:
                self.center = CGPoint(x: ceil((screenSize.width - keyboardSize.height) / 2), y: self.center.y)
            case .landscapeRight:
                self.center = CGPoint(x: screenSize.width - (ceil((screenSize.width - keyboardSize.height) / 2)), y: self.center.y)
            default:
                break
            }
        }
        
        showingKeyboard = true
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        let orientation = UIApplication.orientation
        
        if UIDevice.current.userInterfaceIdiom == .pad && orientation.isPortrait {
            return
        }

        guard let keyboardAnimationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber else {
            DDLogError("[DDSocialDialog] keyboardDidShow: Missing keyboard animation diration user info value")
            return
        }
        
        let screenSize = UIScreen.main.bounds.size
        let duration = keyboardAnimationDuration.doubleValue
        UIView.animate(withDuration: duration) {
            self.center = CGPointMake(ceil(screenSize.width / 2), ceil(screenSize.height / 2))
        }
        
        showingKeyboard = false
    }
}
