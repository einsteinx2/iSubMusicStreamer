//
//  main.swift
//  iSub
//
//  Created by Benjamin Baron on 1/6/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit

// Setup Swift dependency injection
DependencyInjection.setupRegistrations()

// Start app
UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    nil,
    "iSubAppDelegate"
)
