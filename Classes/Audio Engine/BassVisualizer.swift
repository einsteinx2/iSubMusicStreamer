//
//  BassVisualizer.swift
//  iSub
//
//  Created by Benjamin Baron on 1/31/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

enum BassVisualizerType: Int {
    case none = 0
    case fft  = 1
    case line = 2
}

class BassVisualizer: NSObject {
    var type: BassVisualizerType = .none
    var channel: HSTREAM = 0
    
    private let syncObject = NSObject()
    private let fftDataSize = 1024
    private let lineSpecBufSize = 512
    
    private var fftDataBuf = [Float](repeating: 0, count: 1024)
    private var lineSpecBuf = [Int16](repeating: 0, count: 512)
    
    @objc(fftData:) func fftData(index: Int) -> Float {
        guard index >= 0 && index < fftDataSize else { return 0 }
        return synchronized(syncObject) { fftDataBuf[index] }
    }
    
    @objc(lineSpecData:) func lineSpecData(index: Int) -> Int16 {
        guard index >= 0 && index < lineSpecBufSize else { return 0 }
        return synchronized(syncObject) { lineSpecBuf[index] }
    }
    
    func readAudioData() {
        DispatchQueue.default.async {
            synchronized(self.syncObject) {
                guard self.channel > 0 else { return }
                
                // Get the FFT data for visualizer
                if self.type == .fft {
                    BASS_ChannelGetData(self.channel, &self.fftDataBuf, DWORD(BASS_DATA_FLOAT) | BASS_DATA_FFT2048)
                } else if self.type == .line {
                    BASS_ChannelGetData(self.channel, &self.lineSpecBuf, DWORD(self.lineSpecBufSize * MemoryLayout<Int16>.stride))
                }
            }
        }
    }
}
