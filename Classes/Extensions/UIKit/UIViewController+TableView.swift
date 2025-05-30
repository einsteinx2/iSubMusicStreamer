//
//  UIViewController+TableView.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import SnapKit

typealias UITableViewConfiguration = UITableViewDelegate & UITableViewDataSource

extension UIViewController {
    func setupDefaultTableView(_ tableView: UITableView, constraints: ((ConstraintMaker) -> Void)? = nil) {
        if let self = self as? UITableViewConfiguration {
            tableView.delegate = self
            tableView.dataSource = self
        }
        tableView.backgroundColor = Colors.background
        tableView.rowHeight = Defines.rowHeight
        tableView.separatorStyle = .none
        tableView.register(UniversalTableViewCell.self, forCellReuseIdentifier: UniversalTableViewCell.reuseId)
        view.addSubview(tableView)
        if let constraints {
            tableView.snp.makeConstraints(constraints)
        } else {
            tableView.snp.makeConstraints { make in
                make.leading.trailing.top.bottom.equalToSuperview()
            }
        }
    }
}

extension UITableView {
    func dequeueUniversalCell() -> UniversalTableViewCell {
        if let cell = dequeueReusableCell(withIdentifier: UniversalTableViewCell.reuseId) as? UniversalTableViewCell {
            return cell
        }
        return UniversalTableViewCell(style: .default, reuseIdentifier: UniversalTableViewCell.reuseId)
    }
}
