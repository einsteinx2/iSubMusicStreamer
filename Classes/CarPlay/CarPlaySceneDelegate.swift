//
//  CarPlaySceneDelegate.swift
//  iSub
//
//  Created by Ben Baron on 7/18/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit
import CarPlay
import Resolver
import CocoaLumberjackSwift

// Entry point for the CarPlay scene ("CarPlay Configuration" in the Info.plists).
// Deliberately tiny: it kicks the shared bootstrap in case the car connected
// before (or without) the phone scene, then hands the interface controller to
// CarPlayManager, which owns everything else for the life of the connection.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    @Injected private var bootstrap: AppBootstrap

    private var manager: CarPlayManager?

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        DDLogInfo("[CarPlaySceneDelegate] CarPlay scene connected")

        // Idempotent: runs download-lane restore + playback resume only if the
        // phone scene hasn't already
        bootstrap.sceneDidConnect()

        let manager = CarPlayManager(interface: CarPlayInterfaceAdapter(interfaceController: interfaceController))
        self.manager = manager
        manager.connect()
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        DDLogInfo("[CarPlaySceneDelegate] CarPlay scene disconnected")
        manager?.disconnect()
        manager = nil
    }
}
