//
//  Bridging.swift
//  iSub
//
//  Created by Benjamin Baron on 4/6/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

struct Bridging {
    // Immutable

    static func bridge<T : AnyObject>(obj : T) -> UnsafeRawPointer {
        return UnsafeRawPointer(Unmanaged.passUnretained(obj).toOpaque())
    }

    static func bridge<T : AnyObject>(ptr : UnsafeRawPointer) -> T {
        return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
    }

    static func bridgeRetained<T : AnyObject>(obj : T) -> UnsafeRawPointer {
        return UnsafeRawPointer(Unmanaged.passRetained(obj).toOpaque())
    }

    static func bridgeTransfer<T : AnyObject>(ptr : UnsafeRawPointer) -> T {
        return Unmanaged<T>.fromOpaque(ptr).takeRetainedValue()
    }

    // Mutable

    static func bridge<T : AnyObject>(obj : T) -> UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(mutating: UnsafeRawPointer(Unmanaged.passUnretained(obj).toOpaque()))
    }

    static func bridge<T : AnyObject>(ptr : UnsafeMutableRawPointer) -> T {
        return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
    }

    static func bridgeRetained<T : AnyObject>(obj : T) -> UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(mutating: UnsafeRawPointer(Unmanaged.passRetained(obj).toOpaque()))
    }

    static func bridgeTransfer<T : AnyObject>(ptr : UnsafeMutableRawPointer) -> T {
        return Unmanaged<T>.fromOpaque(ptr).takeRetainedValue()
    }
}
