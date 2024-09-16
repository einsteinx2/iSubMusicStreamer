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
        main.register(factory: { Store() as Store }).scope(ResolverScope.application)
        main.register(factory: { SavedSettings() as SavedSettings }).scope(ResolverScope.application)
        main.register(factory: { BassPlayer() as BassPlayer }).scope(ResolverScope.application)
        main.register(factory: { DownloadsManager() as DownloadsManager }).scope(ResolverScope.application)
        main.register(factory: { DownloadQueue() as DownloadQueue }).scope(ResolverScope.application)
        main.register(factory: { StreamManager() as StreamManager }).scope(ResolverScope.application)
        main.register(factory: { Jukebox() as Jukebox }).scope(ResolverScope.application)
        main.register(factory: { PlayQueue() as PlayQueue }).scope(ResolverScope.application)
        main.register(factory: { Social() as Social }).scope(ResolverScope.application)
        main.register(factory: { Analytics() as Analytics }).scope(ResolverScope.application)
    }
}
