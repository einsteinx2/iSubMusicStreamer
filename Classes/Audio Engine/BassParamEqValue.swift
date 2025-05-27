//
//  BassParamEqValue.swift
//  iSub
//
//  Created by Ben Baron on 2/24/24.
//  Copyright © 2024 Ben Baron. All rights reserved.
//

import Foundation

extension BASS_DX8_PARAMEQ: Equatable {
    public static func ==(lhs: BASS_DX8_PARAMEQ, rhs: BASS_DX8_PARAMEQ) -> Bool {
        return lhs.fCenter == rhs.fCenter && lhs.fBandwidth == rhs.fBandwidth && lhs.fGain == rhs.fGain
    }
}

final class BassParamEqValue: NSObject {
    
    var parameters: BASS_DX8_PARAMEQ
    var handle: HFX
    var arrayIndex: Int
    
    var frequency: Float {
        get { return parameters.fCenter }
        set { parameters.fCenter = newValue }
    }
    var bandwidth: Float {
        get { return parameters.fBandwidth }
        set { parameters.fBandwidth = newValue }
    }
    var gain: Float {
        get { return parameters.fGain }
        set { parameters.fGain = newValue }
    }
    
    init(parameters: BASS_DX8_PARAMEQ, handle: HFX = 0, arrayIndex: Int = Int.max) {
        self.parameters = parameters
        self.handle = handle
        self.arrayIndex = arrayIndex
    }
    
    override var hash: Int {
        return Int(abs(parameters.fCenter)) ^ Int(abs(parameters.fGain)) ^ Int(abs(parameters.fBandwidth)) ^ Int(handle)
    }
        
    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? BassParamEqValue else { return false }
        return object === self || (parameters == object.parameters && handle == handle)
    }
}
