//
//  SettingsCoordinator.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit
import SwiftUI
import Resolver

// Drives navigation between the SwiftUI settings screens. Each screen is its own
// UIHostingController pushed onto the app's existing UIKit navigation stack (no inner
// NavigationStack) so global behaviors — server-switch popToRoot on all tabs,
// hidesBottomBarWhenPushed, the iPad menu's cached navigation controllers — keep
// working unchanged.
//
// Lifetime: each hosted screen retains the coordinator through its environment; the
// coordinator only holds a weak reference to the root screen, so everything deallocates
// when the user leaves settings.
final class SettingsCoordinator {
    private weak var rootViewController: UIViewController?

    private var navigationController: UINavigationController? {
        rootViewController?.navigationController
    }

    // Creates the settings root screen. Callers push it (iPhone) or wrap it in a
    // navigation controller (iPad menu); navigation for deeper screens resolves
    // through the root's navigationController at push time.
    func makeRootViewController() -> UIViewController {
        let controller = host(SettingsRootView(), title: "Settings")
        rootViewController = controller
        return controller
    }

    // The controllers to show when settings opens: just the root, or root + server
    // list on first run (no servers yet — the list auto-presents the add sheet).
    // Callers apply these in ONE navigation operation (setViewControllers/push):
    // chaining a second animated push at launch wedges UIKit mid-transition.
    func makeInitialViewControllers() -> [UIViewController] {
        let root = makeRootViewController()
        let store: Store = Resolver.resolve()
        if store.servers().isEmpty {
            return [root, host(ServersView(), title: "Servers")]
        }
        return [root]
    }

    func showSection(_ section: SettingsSection) {
        switch section {
        case .about:
            push(AboutView(), title: "About")
        default:
            push(SettingsSectionView(viewModel: SettingsSectionViewModel(section: section)), title: section.title)
        }
    }

    func showServers() {
        push(ServersView(), title: "Servers")
    }

    func showLicenses() {
        push(LicensesView(), title: "Open Source Licenses")
    }

    func popSettings() {
        navigationController?.popToRootViewController(animated: true)
    }

    private func push<V: View>(_ view: V, title: String) {
        guard let navigationController else { return }
        let controller = host(view, title: title)
        // UIKit silently drops a push made while another transition is running (e.g.
        // the first-run flow pushes Servers from the root screen's onAppear, which
        // fires during the root's own push animation) — defer until it completes.
        // The async hop matters: pushing from inside the transition completion itself
        // leaves the navigation controller in a stuck half-transition.
        if let transitionCoordinator = navigationController.transitionCoordinator {
            transitionCoordinator.animate(alongsideTransition: nil) { _ in
                DispatchQueue.main.async {
                    navigationController.pushViewController(controller, animated: true)
                }
            }
        } else {
            navigationController.pushViewController(controller, animated: true)
        }
    }

    private func host<V: View>(_ view: V, title: String) -> UIViewController {
        let controller = UIHostingController(rootView: AnyView(view.environment(\.settingsCoordinator, self)))
        controller.title = title
        controller.hidesBottomBarWhenPushed = true
        return controller
    }
}

private struct SettingsCoordinatorKey: EnvironmentKey {
    static let defaultValue: SettingsCoordinator? = nil
}

extension EnvironmentValues {
    var settingsCoordinator: SettingsCoordinator? {
        get { self[SettingsCoordinatorKey.self] }
        set { self[SettingsCoordinatorKey.self] = newValue }
    }
}
