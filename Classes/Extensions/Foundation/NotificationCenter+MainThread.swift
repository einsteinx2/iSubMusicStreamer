//
//  NotificationCenter+MainThread.swift
//  iSub
//
//  Created by Benjamin Baron on 1/20/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

import Foundation

private func runOnMainThread(_ block: @escaping () -> Void) {
    if Thread.isMainThread {
        block()
    } else {
        DispatchQueue.main.sync(execute: block)
    }
}

extension NotificationCenter {
    static func postOnMainThread(name: Notification.Name, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        runOnMainThread {
            NotificationCenter.default.post(name: name, object: object, userInfo: userInfo)
        }
    }
    
    static func addObserverOnMainThread(_ observer: AnyObject, selector: Selector, name: Notification.Name, object: AnyObject? = nil) {
        runOnMainThread {
            NotificationCenter.default.addObserver(observer, selector: selector, name: name, object: object)
        }
    }
    
    static func addObserverOnMainThread(name: Notification.Name, object: Any? = nil, block: @escaping (_ notification: Notification) -> Void) -> NSObjectProtocol {
        return NotificationCenter.default.addObserver(forName: name, object: object, queue: OperationQueue.main, using: block)
    }
    
    static func removeObserverOnMainThread(_ observer: AnyObject) {
        runOnMainThread {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    static func removeObserverOnMainThread(_ observer: AnyObject, name: Notification.Name, object: AnyObject? = nil) {
        runOnMainThread {
            NotificationCenter.default.removeObserver(observer, name: name, object: object)
        }
    }
}
