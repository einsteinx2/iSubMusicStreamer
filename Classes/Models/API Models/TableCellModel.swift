//
//  TableCellModel.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc protocol TableCellModel {
    @objc var primaryLabelText: String? { get }
    @objc var secondaryLabelText: String? { get }
    @objc var durationLabelText: String? { get }
    @objc var coverArtId: String? { get }
    @objc var isCached: Bool { get }
    
    @objc func download()
    @objc func queue()
}
