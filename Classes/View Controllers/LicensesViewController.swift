//
//  LicensesViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 12/6/20.
//  Copyright © 2020 Ben Baron. All rights reserved.
//

import UIKit
import WebKit
import SnapKit

@objc final class LicensesViewController: UIViewController {
    let webView = WKWebView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneAction))
        
        webView.allowsBackForwardNavigationGestures = true
        view.addSubview(webView)
        webView.snp.makeConstraints { make in
            make.leading.trailing.top.bottom.equalToSuperview()
        }
        
        if let url = Bundle.main.url(forResource: "open_source_licenses", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url)
        }
    }
    
    @objc private func doneAction() {
        dismiss(animated: true, completion: nil)
    }
}
