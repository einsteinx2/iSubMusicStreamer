//
//  DispatchQueue.swift
//  iSub
//
//  Created by Benjamin Baron on 1/23/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension DispatchQueue {
    // Work that is interacting with the user, such as operating on the main thread, refreshing the user interface, or performing animations. If the work doesn’t happen quickly, the user interface may appear frozen. Focuses on responsiveness and performance.
    // Work is virtually instantaneous.
    static var userInteractive: DispatchQueue { return DispatchQueue.global(qos: .userInteractive) }
    
    // Work that the user has initiated and requires immediate results, such as opening a saved document or performing an action when the user clicks something in the user interface. The work is required in order to continue user interaction. Focuses on responsiveness and performance.
    // Work is nearly instantaneous, such as a few seconds or less.
    static var userInitiated: DispatchQueue   { return DispatchQueue.global(qos: .userInitiated) }
    
    // Default tasks have a lower priority than user-initiated and user-interactive tasks, but a higher priority than utility and background tasks. Assign this class to tasks or queues that your app initiates or uses to perform active work on the user's behalf.
    static var `default`: DispatchQueue       { return DispatchQueue.global(qos: .default) }
    
    // Work that may take some time to complete and doesn’t require an immediate result, such as downloading or importing data. Utility tasks typically have a progress bar that is visible to the user. Focuses on providing a balance between responsiveness, performance, and energy efficiency.
    // Work takes a few seconds to a few minutes.
    static var utility: DispatchQueue         { return DispatchQueue.global(qos: .utility) }
    
    // Work that operates in the background and isn’t visible to the user, such as indexing, synchronizing, and backups. Focuses on energy efficiency.
    // Work takes significant time, such as minutes or hours.
    static var background: DispatchQueue      { return DispatchQueue.global(qos: .background) }
    
    public func async(after timeInterval: TimeInterval, execute work: @escaping () -> Void) {
        let milliseconds = Int(timeInterval * 1000)
        let deadline = DispatchTime.now() + .milliseconds(milliseconds)
        asyncAfter(deadline: deadline, execute: work)
    }
    
    public func async(afterWall timeInterval: TimeInterval, execute work: @escaping () -> Void) {
        let milliseconds = Int(timeInterval * 1000)
        let deadline = DispatchWallTime.now() + .milliseconds(milliseconds)
        asyncAfter(wallDeadline: deadline, execute: work)
    }

    public func async(after timeInterval: TimeInterval, execute: DispatchWorkItem) {
        let milliseconds = Int(timeInterval * 1000)
        let deadline = DispatchTime.now() + .milliseconds(milliseconds)
        asyncAfter(deadline: deadline, execute: execute)
    }
    
    public func asyncAfter(afterWall timeInterval: TimeInterval, execute: DispatchWorkItem) {
        let milliseconds = Int(timeInterval * 1000)
        let deadline = DispatchWallTime.now() + .milliseconds(milliseconds)
        asyncAfter(wallDeadline: deadline, execute: execute)
    }
    
    // Run synchronously, but won't deadlock if called from the main queue
    public static func mainSyncSafe<T>(execute work: () throws -> T) rethrows -> T {
        guard !Thread.isMainThread else {
            // If we're already on the main thread, just execute the block directly to prevent a deadlock
            return try work()
        }
        
        return try DispatchQueue.main.sync(execute: work)
    }
}
