//
//  ItemListViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 1/11/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit

@objc class ItemListViewController: UIViewController {
    let tableView: UITableView
    
    @objc init() {
        self.tableView = UITableView()
        super.init(nibName: nil, bundle: nil)
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
}

@objc extension ItemListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return nil
    }
}

@objc extension ItemListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        fatalError("must override")
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        fatalError("must override")
    }
}
