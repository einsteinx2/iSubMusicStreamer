//
//  SettingsViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/25/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit

final class SettingsViewController: UIViewController {
    let segmentedControl = UISegmentedControl(items: ["Servers", "Options"])
    let controllers: [UIViewController] = [ServersViewController(), OptionsViewController(nibName: "OptionsViewController", bundle: nil)]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Colors.background
        title = "Settings"
        
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        view.addSubview(segmentedControl)
        segmentedControl.snp.makeConstraints { make in
            make.height.equalTo(36)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(7)
            make.leading.equalToSuperview().offset(5)
            make.trailing.equalToSuperview().offset(-5)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        segmentChanged()
    }
    
    @objc private func segmentChanged() {
//        title = segmentedControl.titleForSegment(at: segmentedControl.selectedSegmentIndex)
        
        // Remove other controllers
        for controller in controllers {
            if controller.parent != nil {
                controller.view.removeFromSuperview()
                controller.removeFromParent()
            }
        }
        
        // Reset navigation items
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = nil
        
        let controller = controllers[segmentedControl.selectedSegmentIndex]
        addChild(controller)
        view.addSubview(controller.view)
        controller.view.snp.makeConstraints { make in
            make.top.equalTo(segmentedControl.snp.bottom).offset(7)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
