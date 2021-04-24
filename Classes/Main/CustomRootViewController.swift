//
//  CustomRootViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 2/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

final class CustomRootViewController: UIViewController {
    let mainViewController: UIViewController
    let offlineIndicatorContainer = UIView()
    let offlineIndicatorLabel = UILabel()
    
    init(mainViewController: UIViewController) {
        self.mainViewController = mainViewController
        super.init(nibName: nil, bundle: nil)
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(showOfflineIndicator), name: Notifications.didEnterOfflineMode)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(hideOfflineIndicator), name: Notifications.didEnterOnlineMode)
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        addChild(mainViewController)
        view.addSubview(mainViewController.view)
        mainViewController.view.snp.makeConstraints { make in
            make.leading.trailing.top.bottom.equalToSuperview()
        }
        
        offlineIndicatorContainer.backgroundColor = .black
        view.addSubview(offlineIndicatorContainer)
        offlineIndicatorContainer.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(mainViewController.view.snp.bottom)
        }
        
        offlineIndicatorLabel.alpha = 0
        offlineIndicatorLabel.backgroundColor = .black
        offlineIndicatorLabel.textColor = .white
        offlineIndicatorLabel.font = .systemFont(ofSize: UIDevice.isSmall ? 12 : 14)
        offlineIndicatorLabel.textAlignment = .center
        offlineIndicatorLabel.text = "iSub is Offline"
        offlineIndicatorContainer.addSubview(offlineIndicatorLabel)
        offlineIndicatorLabel.snp.makeConstraints { make in
            make.height.equalTo(20)
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(UIDevice.isSmall ? 0 : 5)
        }
    }
    
    @objc func showOfflineIndicator() {
        UIView.animate(withDuration: 0.6) {
            self.offlineIndicatorLabel.alpha = 1
        }
        UIView.animate(withDuration: 0.3) {
            self.mainViewController.view.snp.updateConstraints { make in
                make.bottom.equalToSuperview().offset(-self.view.safeAreaInsets.bottom - 22)
            }
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func hideOfflineIndicator() {
        UIView.animate(withDuration: 0.3) {
            self.offlineIndicatorLabel.alpha = 0
            self.mainViewController.view.snp.updateConstraints { make in
                make.bottom.equalToSuperview()
            }
            self.view.layoutIfNeeded()
        }
    }
}
