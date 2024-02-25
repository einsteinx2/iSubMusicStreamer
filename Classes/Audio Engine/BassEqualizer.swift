//
//  BassEqualizer.swift
//  iSub
//
//  Created by Ben Baron on 2/24/24.
//  Copyright © 2024 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import Resolver

private let equalizerGainReduction: Float = 0.45

@objc final class BassEqualizer: NSObject {
    @LazyInjected private var settings: SavedSettings
    
    private(set) var isEqActive = false
    @objc var channel: HCHANNEL = 0 {
        willSet {
            if channel != newValue {
                // Remove any EQ points
                removeAllEqualizerValues()
            }
        }
    }
    @objc var gain: Float = 0.0 {
        didSet {
            var modifiedGainValue = isEqActive ? gain - equalizerGainReduction : gain
            modifiedGainValue = modifiedGainValue < 0.0 ? 0.0 : modifiedGainValue
            
            var volume = BASS_BFX_VOLUME(lChannel: 0, fVolume: modifiedGainValue)
            BASS_FXSetParameters(volumeFx, &volume)
        }
    }
    
    // TODO: See if this can be removed since Swift should copy the array anyway
    @objc var equalizerValues: [BassParamEqValue] {
        return eqValuesLock.sync {
            let values = eqValues
            return values
        }
//        eqValuesLock.lock()
//        let values = eqValues
//        eqValuesLock.unlock()
//        return values
    }
    
    private var eqHandles = [HFX]()
    private var eqValues = [BassParamEqValue]()
    private let eqValuesLock = NSRecursiveLock()
    private var volumeFx: HFX = 0
    private var limiterFx: HFX = 0
    
    @objc func clearEqualizerValues() {
        if channel > 0 {
            for handle in eqHandles {
                BASS_ChannelRemoveFX(channel, handle)
            }
        }
        
        eqValuesLock.sync {
            for value in eqValues {
               value.handle = 0
           }
        }
//        eqValuesLock.lock()
//        for value in eqValues {
//            value.handle = 0
//        }
//        eqValuesLock.unlock()
        
        eqHandles.removeAll()
        isEqActive = false
    }
    
    @objc func applyEqualizerValues() {
        applyEqualizerValues(values: eqValues)
    }
    
    @objc(applyEqualizerValues:)
    func applyEqualizerValues(values: [BassParamEqValue]) {
        guard values.count > 0, channel > 0 else { return }
        
        for value in values {
            let handle = BASS_ChannelSetFX(channel, DWORD(BASS_FX_DX8_PARAMEQ), 10);
            BASS_FXSetParameters(handle, &value.parameters)
            
            value.handle = handle
            eqHandles.append(handle)
        }
        isEqActive = true
    }
    
    @objc(updateEqParameter:)
    func updateEqParameter(value: BassParamEqValue) {
        eqValuesLock.sync {
            if eqValues.count > value.arrayIndex {
                eqValues[value.arrayIndex] = value
            }
        }
//        eqValuesLock.lock()
//        if eqValues.count > value.arrayIndex {
//            eqValues[value.arrayIndex] = value
//        }
//        eqValuesLock.unlock()
        
        if isEqActive {
            if Debug.audioEngine {
                DDLogInfo("[BassEqualizer] updating eq for handle: \(value.handle) new freq: \(value.frequency) new gain: \(value.gain)")
            }
            BASS_FXSetParameters(value.handle, &value.parameters);
        }
    }
    
    @objc(addEqualizerValue:)
    @discardableResult
    func addEqualizerValue(value: BASS_DX8_PARAMEQ) -> BassParamEqValue {
        guard channel > 0 else { return BassParamEqValue(parameters: BASS_DX8_PARAMEQ()) }
        
        let eqValue = eqValuesLock.sync {
            let eqValue = BassParamEqValue(parameters: value, arrayIndex:eqValues.count)
            eqValues.append(eqValue)
            return eqValue
        }
//        eqValuesLock.lock()
//        let eqValue = BassParamEqValue(parameters: value, arrayIndex:eqValues.count)
//        eqValues.append(eqValue)
//        eqValuesLock.unlock()
    
        if isEqActive {
            let handle = BASS_ChannelSetFX(channel, DWORD(BASS_FX_DX8_PARAMEQ), 10);
            var mutValue = value
            BASS_FXSetParameters(handle, &mutValue);
            eqValue.handle = handle;
            
            eqHandles.append(handle)
        }
        
        return eqValue
    }
    
    
    @objc(removeEqualizerValue:)
    func removeEqualizerValue(value: BassParamEqValue) {
        print("removeEqualizerValue");
        if isEqActive && channel > 0 {
            // Disable the effect channel
            BASS_ChannelRemoveFX(channel, value.handle);
        }
        
        // Remove the handle
        eqHandles.removeAll { $0 == value.handle }
        
        // Remove the value
        eqValuesLock.sync {
            eqValues.remove(at: value.arrayIndex)
            for i in value.arrayIndex..<eqValues.count {
                // Adjust the arrayIndex values for the other objects
                eqValues[i].arrayIndex = i
            }
        }
//        eqValuesLock.lock()
//        eqValues.remove(at: value.arrayIndex)
//        for i in value.arrayIndex..<eqValues.count {
//            // Adjust the arrayIndex values for the other objects
//            eqValues[i].arrayIndex = i
//        }
//        eqValuesLock.unlock()
    }
    
    @objc func removeAllEqualizerValues() {
        clearEqualizerValues()
        
        eqValuesLock.sync {
            eqValues.removeAll()
        }
//        eqValuesLock.lock()
//        eqValues.removeAll()
//        eqValuesLock.unlock()

        isEqActive = false
    }
    
    @objc @discardableResult
    func toggleEqualizer() -> Bool {
        settings.isEqualizerOn = !isEqActive
        
        if isEqActive {
            clearEqualizerValues()
        } else {
            // TODO: See if this lock and copy is necessary
            let values = eqValuesLock.sync {
                let values = eqValues
                return values
            }
//            eqValuesLock.lock()
//            let values = eqValues
//            eqValuesLock.unlock()
            applyEqualizerValues(values: values)
        }
        gain = settings.gainMultiplier
        
        return !isEqActive
    }
    
    @objc func createVolumeFx() {
        guard channel > 0 else { return }
        
        if volumeFx > 0 {
            BASS_ChannelRemoveFX(channel, volumeFx)
        }
        
        // Enable BASS_FX plugin
        BASS_FX_GetVersion()
        
        volumeFx = BASS_ChannelSetFX(channel, DWORD(BASS_FX_BFX_VOLUME), 50)
        gain = settings.gainMultiplier
    }
    
    @objc func createLimiterFx() {
        guard channel > 0 else { return }
        
        if limiterFx > 0 {
            BASS_ChannelRemoveFX(channel, limiterFx)
        }
        
        // Enable BASS_FX plugin
        BASS_FX_GetVersion();

        limiterFx = BASS_ChannelSetFX(channel, DWORD(BASS_FX_BFX_COMPRESSOR2), 100)
        var limiterParams = BASS_BFX_COMPRESSOR2(fGain: 0,       // extra output gain
                                                 fThreshold: -3, // -3 dB
                                                 fRatio: 15,     // bottom end of limiter ratio range, 20 would be a hard brick wall limiter
                                                 fAttack: 0.25,  // 0.25 ms
                                                 fRelease: 0.25, // 0.25 ms
                                                 lChannel: Int32(BASS_BFX_CHANALL))
        BASS_FXSetParameters(channel, &limiterParams)
    }
    
    deinit {
        removeAllEqualizerValues()
    }
}
