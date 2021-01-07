//
//  DependencyInjection.swift
//  iSub
//
//  Created by Benjamin Baron on 1/6/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

struct DependencyInjection {
    private static let resolver = Resolver()
    
    static func setupRegistrations() {
        let main = Resolver.main
        
        // Singletons
        main.register(factory: { Store() as Store }).scope(Resolver.application)
    }
}
