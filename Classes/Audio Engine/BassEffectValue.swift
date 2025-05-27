//
//  BassEffectValue.swift
//  iSub
//
//  Created by Ben Baron on 2/24/24.
//  Copyright © 2024 Ben Baron. All rights reserved.
//

import Foundation

class BassEffectValue: NSObject {
    let type: BassEffectType
    let percentX: Float
    let percentY: Float
    let isDefault: Bool
    
    init(type: BassEffectType, percentX: Float, percentY: Float, isDefault: Bool) {
        self.type = type
        self.percentX = percentX
        self.percentY = percentY
        self.isDefault = isDefault
    }
}
