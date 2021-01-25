//
//  TableCellModel.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

protocol TableCellModel {
    var primaryLabelText: String? { get }
    var secondaryLabelText: String? { get }
    var durationLabelText: String? { get }
    var coverArtId: String? { get }
    var isCached: Bool { get }
    
    func download()
    func queue()
}
