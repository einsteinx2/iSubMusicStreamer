//
//  OBSlider.m
//
//  Created by Ole Begemann on 02.01.11.
//  Copyright 2011 Ole Begemann. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------ ^^ Original license message ------------------------
//
// Modified and ported to Swift by Ben Baron, original license applies.
//

import UIKit

// How many extra touchable pixels you want above and below the 23px slider
private let heightExtension: CGFloat = 100
private let heightExtensionPad: CGFloat = 30

final class OBSlider: UISlider {
    var scrubbingSpeeds: [Float] = [1.0, 0.5, 0.25, 0.1]
    var scrubbingSpeedChangePositions: [Float] = [0.0, 50.0, 100.0, 150.0]
    private(set) var scrubbingSpeed: Float = 1.0
    
    private var beganTrackingLocation: CGPoint = .zero
    private var realPositionValue: Float = 0.0
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let extensionY = UIDevice.isPad ? heightExtensionPad : heightExtension
        let bounds = self.bounds.insetBy(dx: 0, dy: -extensionY)
        return bounds.contains(point)
    }
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let beginTracking = super.beginTracking(touch, with: event)
        if beginTracking {
            beganTrackingLocation = touch.location(in: self)
            realPositionValue = value
        }
        return beginTracking
    }
    
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard isTracking else { return false }
        
        let previousLocation = touch.previousLocation(in: self)
        let currentLocation = touch.location(in: self)
        let trackingOffset = currentLocation.x - previousLocation.x
        
        // Find the scrubbing speed that curresponds to the touch's vertical offset
        let verticalOffset = abs(currentLocation.y - beganTrackingLocation.y)
        var scrubbingSpeedChangePosIndex = indexOfLowerScrubbingSpeed(positions: scrubbingSpeedChangePositions, forOffset: Float(verticalOffset))
        if scrubbingSpeedChangePosIndex == NSNotFound {
            scrubbingSpeedChangePosIndex = scrubbingSpeeds.count
        }
        scrubbingSpeed = scrubbingSpeeds[scrubbingSpeedChangePosIndex - 1]
        
        let trackRect = self.trackRect(forBounds: bounds)
        realPositionValue += (maximumValue - minimumValue) * Float(trackingOffset / trackRect.size.width)
        if (beganTrackingLocation.y < currentLocation.y && currentLocation.y < previousLocation.y) || (beganTrackingLocation.y > currentLocation.y && currentLocation.y > previousLocation.y) {
            // We are getting closer to the slider, go closer to the real location
            value += scrubbingSpeed * (maximumValue - minimumValue) * Float(trackingOffset / trackRect.size.width) + (realPositionValue - value) / Float(1 + abs(currentLocation.y - beganTrackingLocation.y))
        } else {
            value += scrubbingSpeed * (maximumValue - minimumValue) * Float(trackingOffset / trackRect.size.width)
        }
        
        if isContinuous {
            sendActions(for: .valueChanged)
        }
        
        return isTracking
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        guard isTracking else { return }
        
        scrubbingSpeed = scrubbingSpeeds[0]
        sendActions(for: .valueChanged)
    }
    
    // Return the lowest index in the array of numbers passed in scrubbingSpeedPositions
    // whose value is smaller than verticalOffset.
    private func indexOfLowerScrubbingSpeed(positions: [Float], forOffset verticalOffset: Float) -> Int {
        for (i, offset) in positions.enumerated() {
            if verticalOffset < offset {
                return i
            }
        }
        return NSNotFound
    }
}
