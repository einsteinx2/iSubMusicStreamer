//
//  EqualizerPathView.swift
//  iSub
//
//  Created by Ben Baron on 2/25/24.
//  Copyright © 2024 Ben Baron. All rights reserved.
//

import Resolver

let MIN_FREQUENCY = 32
let MAX_FREQUENCY = 16384
let RANGE_OF_EXPONENTS = 9

let MIN_GAIN = -6
let MAX_GAIN = 6

let DEFAULT_BANDWIDTH = 18

@objc final class EqualizerPathView: UIView {
    
    @Injected private var settings: SavedSettings
    
    var points = [CGPoint]() {
        didSet {
            setNeedsDisplay()
        }
    }
    
    private let strokeColor = CGColor(gray: 1, alpha: 0.5)
    private let fillColorOff = CGColor(gray: 1, alpha: 0.25)
    private let fillColorOn = CGColor(red: 98.0/255.0, green: 180.0/255.0, blue: 223.0/255.0, alpha: 0.5)
    
    private func string(fromFreq frequency: Int) -> String {
        return frequency < 1000 ? "\(frequency)" : "\(frequency/1000)k"
    }
    
    private func string(fromGain gain: Float) -> String {
        let format = gain == 0.0 || gain == abs(gain) ? "%.0fdB" : "%.1fdB"
        return String(format: format, gain)
    }
    
    private func drawTextLabel(at point: CGPoint, string: String) {
        guard let font = UIFont(name: "Arial", size: 10) else { return }
        
        let nsstring = string as NSString
        let attributes = [NSAttributedString.Key.font: font, NSAttributedString.Key.foregroundColor: UIColor.white]
        nsstring.draw(at: point, withAttributes: attributes)
    }
    
    private func drawTicksAndLabels() {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Set font properties
        context.setBlendMode(.normal)
        context.textMatrix = CGAffineTransformMake(1.0, 0.0, 0.0, -1.0, 0.0, 0.0)
        context.setTextDrawingMode(.fill)
        
        // Set drawing properties
        context.setStrokeColor(strokeColor)
        context.setFillColor(strokeColor)
        context.setLineWidth(1)
        
        // Create freq ticks and labels
        let bottom = frame.height
        let tickHeight = frame.height / 30.0
        let tickGap = frame.width / CGFloat(RANGE_OF_EXPONENTS)

        for i in 0...RANGE_OF_EXPONENTS {
            context.move(to: CGPoint(x: CGFloat(i) * tickGap, y: bottom))
            context.addLine(to: CGPoint(x: CGFloat(i) * tickGap, y: bottom - tickHeight))
            
            let freqPoint = CGPoint(x: CGFloat(i) * tickGap + 4, y: bottom - (tickHeight * 0.75))
            let freqString = string(fromFreq: MIN_FREQUENCY * Int(pow(2, Double(i))))
            drawTextLabel(at: freqPoint, string: freqString)
        }
        let freqPoint = CGPoint(x: CGFloat(RANGE_OF_EXPONENTS) * tickGap - 20, y: bottom - (tickHeight * 0.75))
        let freqString = string(fromFreq: MIN_FREQUENCY * Int(pow(2, Double(RANGE_OF_EXPONENTS))))
        drawTextLabel(at: freqPoint, string: freqString)

        // Create the decibel ticks and labels
        let leftTickGap = frame.height / 4
        let decibelGap = Float(MAX_GAIN) / 2
        for i in 0...3 {
            context.move(to: CGPoint(x: 0, y: CGFloat(i) * leftTickGap))
            if i == 2 {
                // Draw the center line all the way across
                context.addLine(to: CGPoint(x: frame.width, y: CGFloat(i) * leftTickGap))
            } else {
                context.addLine(to: CGPoint(x: tickHeight, y: CGFloat(i) * leftTickGap))
            }
            
            let decibelPoint = CGPoint(x: 0, y: CGFloat(i) * leftTickGap + 4)
            let decibelString = string(fromGain: Float(MAX_GAIN) - (decibelGap * Float(i)))
            drawTextLabel(at: decibelPoint, string: decibelString)
        }
        let decibelPoint = CGPoint(x: 0, y: 4 * leftTickGap - 30)
        let decibelString = string(fromGain: Float(MAX_GAIN) - (decibelGap * 4))
        drawTextLabel(at: decibelPoint, string: decibelString)
        context.strokePath()
    }
    
    private func drawCurve() {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        let octaveWidth = frame.width / CGFloat(RANGE_OF_EXPONENTS)
        let eqWidth = (CGFloat(DEFAULT_BANDWIDTH) / 12) * octaveWidth
        let halfEqWidth = eqWidth / 2

        context.setFillColor(settings.isEqualizerOn ? fillColorOn : fillColorOff)
        context.setBlendMode(.lighten)

        for i in 0..<points.count {
            let point = points[i]
            
            let start = CGPoint(x: point.x - halfEqWidth, y: center.y)
            let end = CGPoint(x: point.x + halfEqWidth, y: center.y)
            
            let modifier = CGFloat(point.y < center.y ? -1 : 1)
            let half = abs(point.y - center.y)
            let controlY = point.y + half * modifier
            let control = CGPoint(x: point.x, y: controlY)
            
            context.move(to: start)
            context.addQuadCurve(to: end, control: control)
            context.fillPath()
        }
    }
        
    @objc override func draw(_ rect: CGRect) {
        // Draw the axis labels
        drawTicksAndLabels()
            
        // Smooth and draw the eq path
        drawCurve()
    }
}
