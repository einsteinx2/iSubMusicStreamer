//
//  EqualizerPointView.swift
//  iSub
//
//  Created by Benjamin Baron on 2/1/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit

private let defaultWidth: CGFloat = 30
private let defaultHeight: CGFloat = 30
private let rangeOfExponents: Float = 9
private let maxGain: Float = 6

private let defaultBandwidth: Float = 18

private func percentX(frequency: Float) -> CGFloat {
    return CGFloat((log2(frequency) - 5) / 9)
}

func percentY(gain: Float) -> CGFloat {
    return CGFloat(0.5 - (gain / (maxGain * 2)))
}

@objc final class EqualizerPointView: UIImageView {
    private var _eqValue: BassParamEqValue
    @objc var eqValue: BassParamEqValue {
        get {
            _eqValue.gain = gain
            _eqValue.frequency = frequency
            _eqValue.bandwidth = defaultBandwidth
            return _eqValue
        }
        set {
            _eqValue = newValue
        }
    }
    @objc var position: CGPoint
    @objc var parentSize: CGSize
    @objc var handle: HFX = 0
    
    @objc var frequency: Float { exp2((Float(position.x) * rangeOfExponents) + 5) }
    @objc var gain: Float { (0.5 - Float(position.y)) * Float(maxGain * 2) }
    
    override var center: CGPoint {
        didSet {
            position.x = center.x / parentSize.width
            position.y = center.y / parentSize.height
        }
    }
    
    @objc init(point: CGPoint, parentSize: CGSize) {
        let p = BASS_DX8_PARAMEQ(fCenter: 0, fBandwidth: Float(defaultBandwidth), fGain: 0)
        self._eqValue = BassParamEqValue(parameters: p)
        self.position = CGPoint(x: point.x / parentSize.width, y: point.y / parentSize.height)
        self.parentSize = parentSize
        super.init(frame: CGRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight))
        self.center = point
        self.image = UIImage(named: "eqView")
        self.isUserInteractionEnabled = true
    }
    
    @objc init(eqValue: BassParamEqValue, parentSize: CGSize) {
        self._eqValue = eqValue
        self.parentSize = parentSize
        let x = percentX(frequency: eqValue.parameters.fCenter)
        let y = percentY(gain: eqValue.parameters.fGain)
        self.position = CGPoint(x: x, y: y)
        super.init(frame: CGRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight))
        self.center = CGPoint(x: parentSize.width * position.x, y: parentSize.height * position.y)
        self.image = UIImage(named: "eqView")
        self.isUserInteractionEnabled = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    @objc func compare(other: EqualizerPointView) -> ComparisonResult {
        let myX = frame.origin.x
        let otherX = other.frame.origin.x
        if myX < otherX {
            return .orderedAscending
        } else if myX > otherX {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }
}
