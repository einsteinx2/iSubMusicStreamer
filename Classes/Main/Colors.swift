//
//  Colors.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit

struct Colors {
    static let background = UIColor(named: "isubBackgroundColor")
    static let window = UIColor(white: 0.3, alpha: 1)
    static let jukeboxWindow = UIColor(red: 140.0/255.0, green: 0, blue: 0, alpha: 1)
    
    static let playerButton = UIColor(named: "isubPlayerButtonColor")
    static let playerButtonActivated = UIColor.systemBlue
    
    // Table cell downloaded status colors
    static let cellRed = UIColor(red: 226.0/255.0, green: 0, blue: 0, alpha: 1)
    static let cellYellow = UIColor(red: 1, green: 215.0/255.0, blue: 0, alpha: 1)
    static let cellGreen = UIColor(red: 103.0/255.0, green: 227.0/255.0, blue: 0, alpha: 1)
    static let cellBlue = UIColor(red: 28.0/255.0, green: 163.0/255.0, blue: 1, alpha: 1)
    static var currentCellColor: UIColor {
        switch SavedSettings.shared().downloadedSongCellColorType {
            case 0: return cellRed;
            case 1: return cellYellow;
            case 2: return cellGreen;
            case 3: return cellBlue;
            default: return cellBlue;
        }
    }
}
