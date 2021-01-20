//
//  PlaylistsViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

final class PlaylistsViewController: UIViewController {    
    let segmentedControl = UISegmentedControl(items: ["Play Queue", "Local", "Server"])
    let controllers: [UIViewController] = [PlayQueueViewController(), LocalPlaylistsViewController(), ServerPlaylistsViewController()]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Colors.background
        title = "Playlists"
        
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        view.addSubview(segmentedControl)
        segmentedControl.snp.makeConstraints { make in
            make.height.equalTo(36)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(7)
            make.leading.equalToSuperview().offset(5)
            make.trailing.equalToSuperview().offset(-5)
        }
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(addURLRefBackButton), name: UIApplication.didBecomeActiveNotification)
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
                
        addURLRefBackButton()
        addShowPlayerButton()

        segmentChanged()
        Flurry.logEvent("PlaylistsTab")
    }
    
    @objc private func segmentChanged() {
        // Remove other controllers
        for controller in controllers {
            if controller.parent != nil {
                controller.view.removeFromSuperview()
                controller.removeFromParent()
            }
        }
        
        let controller = controllers[segmentedControl.selectedSegmentIndex]
        addChild(controller)
        view.addSubview(controller.view)
        controller.view.snp.makeConstraints { make in
            make.top.equalTo(segmentedControl.snp.bottom).offset(7)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
