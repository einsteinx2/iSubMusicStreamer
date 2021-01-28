//
//  UIDevice+Info.swift
//  iSub
//
//  Created by Benjamin Baron on 1/27/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

@objc extension UIDevice {
    static var isPad: Bool {
        Self.current.userInterfaceIdiom == .pad
    }
    
    static var isSmall: Bool {
        // Should match iPhone SE 2nd Edition and iPhone 6/7/8 (all phones with home buttons)
        let size = UIScreen.main.bounds.size
        let length = UIApplication.orientation.isPortrait ? size.height : size.width
        return length < 700
    }
    
    static func sysctl(name: String) -> String {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        var value = [CChar](repeating: 0,  count: size)
        sysctlbyname(name, &value, &size, nil, 0)
        return String(cString: value)
    }
    
    // The device model identifier e.g. "iPhone12,5"
    static var deviceModel: String {
        sysctl(name: "hw.machine")
    }
    
    // The kernel version number e.g. "18C66"
    static var kernelVersion: String {
        sysctl(name: "kern.osversion")
    }
    
    // The complete OS version string e.g. "iOS 14.3 (18C66)"
    static var completeOSVersion: String {
        "\(Self.current.systemName) \(Self.current.systemVersion) (\(kernelVersion))"
    }
}
