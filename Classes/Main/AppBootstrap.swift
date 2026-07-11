//
//  AppBootstrap.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit
import CocoaLumberjackSwift

// The single place that encodes the app's order-sensitive startup sequence
// (Phase 8.11). Every step below is annotated with its invariant; reordering is
// a bug. UI concerns (window construction, observers, battery monitoring,
// notification authorization, URL schemes) stay in AppDelegate/SceneDelegate.
final class AppBootstrap {
    private let services: AppServices

    init(services: AppServices) {
        self.services = services
    }

    // The service half of application(_:didFinishLaunchingWithOptions:)
    func launch() {
        // UI test mode: wipe state before anything touches disk or defaults
        UITestSupport.resetStateIfRequested()

        // Initialize database
        services.store.setup()

        // UI test mode: stub the network and seed a pre-configured server.
        // INVARIANT: after store.setup() and before settings.setup(store:), which
        // loads the seeded current server
        UITestSupport.configureIfEnabled()

        // Setup services (constructed and wired in DependencyInjection.swift)
        services.settings.setup(store: services.store)
        services.downloadsManager.setup()

        // Restore playback state and start the periodic save timer.
        // INVARIANT: must run before sceneDidConnect() — loadState() writes the play
        // queue indices and player offsets that resumeSong() reads
        services.stateRestorer.setup()

        // Detect app crash on previous launch (RELEASE-only by design)
        #if RELEASE
        services.settings.appCrashedOnLastRun = !services.settings.appTerminatedCleanly
        services.settings.appTerminatedCleanly = false
        #endif

        // Initialize the lock screen controls and now playing info
        services.nowPlayingService.setup()

        // Enable console logging for Xcode builds
        #if DEBUG
        DDLog.add(DDOSLogger.sharedInstance)
        #endif

        // Enable file logging (Use local time zone when formatting dates)
        let dateFormatter = DateFormatter()
        dateFormatter.formatterBehavior = .behavior10_4
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss:SSS"
        let fileLogger = DDFileLogger()
        fileLogger.logFormatter = DDLogFileFormatterDefault(dateFormatter: dateFormatter)
        fileLogger.rollingFrequency = 60 * 60 * 24 // 24 hour rolling
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.add(fileLogger)

        // Set default log level (verbose logs only included in beta builds)
        Defines.setupDefaultLogLevel()

        // Log system info
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "Unknown"
        let build = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] ?? "Unknown"
        DDLogInfo("\n---------------------------------\niSub \(version) build \(build) launched\n---------------------------------")

        // Load Flurry
        services.analytics.setup()
    }

    // The playback-recovery kickoff from scene(_:willConnectTo:).
    // INVARIANT: runs after launch() (state restoration) and after SceneDelegate has
    // registered its observers, so resumeSong-triggered notifications are seen
    func sceneDidConnect() {
        services.downloadEngine.setup()
        services.playbackCoordinator.resumeSong()
    }

    // Called if the application terminates without crashing
    func terminate() {
        // Save settings and state
        services.settings.appTerminatedCleanly = true

        // Cleanly terminate audio
        UIApplication.shared.endReceivingRemoteControlEvents()
        services.player.stop()
    }
}
