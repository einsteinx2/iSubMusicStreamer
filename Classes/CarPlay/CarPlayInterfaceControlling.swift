//
//  CarPlayInterfaceControlling.swift
//  iSub
//
//  Created by Ben Baron on 7/18/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import CarPlay
import CocoaLumberjackSwift

// Thin seam over CPInterfaceController so CarPlayManager can be unit tested with a
// recording fake — CPInterfaceController has no public initializer, so the real
// thing only exists inside a live CarPlay session.
protocol CarPlayInterfaceControlling: AnyObject {
    // The current template stack, root first (root tab bar + pushed templates)
    var templates: [CPTemplate] { get }
    var topTemplate: CPTemplate? { get }
    var carTraitCollection: UITraitCollection { get }
    // Fires on main after the stack changes for any reason — including the user
    // navigating back — so the owner can prune its screen bookkeeping
    var onStackChanged: (() -> Void)? { get set }

    func setRootTemplate(_ template: CPTemplate, animated: Bool)
    func pushTemplate(_ template: CPTemplate, animated: Bool)
    func popTemplate(animated: Bool)
    func popToRootTemplate(animated: Bool)
}

final class CarPlayInterfaceAdapter: NSObject, CarPlayInterfaceControlling {
    private let interfaceController: CPInterfaceController

    var onStackChanged: (() -> Void)?

    init(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        super.init()
        interfaceController.delegate = self
    }

    var templates: [CPTemplate] { interfaceController.templates }
    var topTemplate: CPTemplate? { interfaceController.topTemplate }
    var carTraitCollection: UITraitCollection { interfaceController.carTraitCollection }

    func setRootTemplate(_ template: CPTemplate, animated: Bool) {
        interfaceController.setRootTemplate(template, animated: animated) { _, error in
            if let error {
                DDLogError("[CarPlayInterfaceAdapter] setRootTemplate failed: \(error)")
            }
        }
    }

    func pushTemplate(_ template: CPTemplate, animated: Bool) {
        interfaceController.pushTemplate(template, animated: animated) { _, error in
            if let error {
                DDLogError("[CarPlayInterfaceAdapter] pushTemplate failed: \(error)")
            }
        }
    }

    func popTemplate(animated: Bool) {
        interfaceController.popTemplate(animated: animated) { _, error in
            if let error {
                DDLogError("[CarPlayInterfaceAdapter] popTemplate failed: \(error)")
            }
        }
    }

    func popToRootTemplate(animated: Bool) {
        interfaceController.popToRootTemplate(animated: animated) { _, error in
            if let error {
                DDLogError("[CarPlayInterfaceAdapter] popToRootTemplate failed: \(error)")
            }
        }
    }
}

extension CarPlayInterfaceAdapter: CPInterfaceControllerDelegate {
    func templateDidAppear(_ aTemplate: CPTemplate, animated: Bool) {
        onStackChanged?()
    }

    func templateDidDisappear(_ aTemplate: CPTemplate, animated: Bool) {
        onStackChanged?()
    }
}
