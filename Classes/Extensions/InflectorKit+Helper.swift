//
//  InflectorKit+Helper.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import InflectorKit

import Foundation

extension String {
    func pluralize(amount: Int) -> String {
        return amount == 1 ? self : self.pluralized
    }
}


