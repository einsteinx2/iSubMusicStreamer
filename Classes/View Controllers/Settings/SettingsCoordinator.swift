//
//  SettingsCoordinator.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit
import SwiftUI

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

    func showSection(_ section: SettingsSection) {
        switch section {
        case .about:
            push(AboutView(), title: "About")
        default:
            push(SettingsSectionView(viewModel: SettingsSectionViewModel(section: section)), title: section.title)
        }
    }

    func showServers() {
        // Replaced with the SwiftUI ServersView in the servers phase
    }

    func showLicenses() {
        push(LicensesView(), title: "Open Source Licenses")
    }

    func popSettings() {
        navigationController?.popToRootViewController(animated: true)
    }

    private func push<V: View>(_ view: V, title: String) {
        navigationController?.pushViewController(host(view, title: title), animated: true)
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
