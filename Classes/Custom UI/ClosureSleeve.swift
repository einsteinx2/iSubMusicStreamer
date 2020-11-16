//
//  ClosureSleeve.swift
//  iSub
//
//  Created by Benjamin Baron on 11/13/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

// Example from: https://stackoverflow.com/a/49259126/299262
// Wraps a closure/block allowing any UIControl to use blocks for actions

import UIKit

// Simple wrapper for closure/blocks to "objectify" them allowing them to be used for things that require a selector
@objc class ClosureSleeve: NSObject {
    let closure: ()->()
    
    init(closure: @escaping ()->()) {
        self.closure = closure
    }
    
    // Available as a selector for use as a handler
    @objc func invoke() {
        closure()
    }
}

@objc extension UIControl {
    // Adds a closure/block as an action instead of using an Objective-C method
    func addClosure(for controlEvents: UIControl.Event, closure: @escaping ()->()) {
        // "Sleeve" the closure to wrap it in an object so we can use the invoke method as the action handler
        let sleeve = ClosureSleeve(closure: closure)
        
        // Set the closure as the action handler
        addTarget(sleeve, action: #selector(ClosureSleeve.invoke), for: controlEvents)
        
        // Have the control keep a reference to the closure "sleeve"
        objc_setAssociatedObject(self, String(controlEvents.rawValue), sleeve, .OBJC_ASSOCIATION_RETAIN)
    }
}
