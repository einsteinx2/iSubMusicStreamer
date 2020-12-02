//
//  PadRootViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 11/22/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

@objc class PadRootViewController: UIViewController {
    private let rootView = UIView()
    @objc let menuViewController = PadMenuViewController()
    @objc var currentContentNavigationController: UINavigationController?
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Color under the status bar
        view.backgroundColor = .black
        
        // Container to hold all views under the status bar
        rootView.backgroundColor = UIColor(named: "isubBackgroundColor")
        rootView.frame = view.bounds
        view.addSubview(rootView)
        rootView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalToSuperview().offset(22)
        }
        
        addChild(menuViewController)
        rootView.addSubview(menuViewController.view)
        menuViewController.view.snp.makeConstraints { make in
            make.width.equalTo(300)//(320)//256)
            make.leading.top.bottom.equalToSuperview()
        }
    }
    
    func switchContentViewController(controller: UINavigationController) {
        // Remove current content view controller
        currentContentNavigationController?.view.removeFromSuperview()
        currentContentNavigationController?.removeFromParent()
        
        // Add new content view controller
        addChild(controller)
        rootView.addSubview(controller.view)
        controller.view.snp.makeConstraints { make in
            make.leading.equalTo(menuViewController.view.snp.trailing)
            make.trailing.top.bottom.equalToSuperview()
        }
        currentContentNavigationController = controller
    }
}
