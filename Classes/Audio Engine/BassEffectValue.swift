//
//  BassEffectValue.swift
//  iSub
//
//  Created by Ben Baron on 2/24/24.
//  Copyright © 2024 Ben Baron. All rights reserved.
//

import Foundation

@objc class BassEffectValue: NSObject {
    @objc let type: BassEffectType
    @objc let percentX: Float
    @objc let percentY: Float
    @objc let isDefault: Bool
    
    @objc init(type: BassEffectType, percentX: Float, percentY: Float, isDefault: Bool) {
        self.type = type
        self.percentX = percentX
        self.percentY = percentY
        self.isDefault = isDefault
    }
}
