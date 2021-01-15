//
//  SaveEditHeader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import SnapKit
import InflectorKit

@objc protocol SaveEditHeaderDelegate {
    func saveEditHeaderSaveDeleteAction(_ saveEditHeader: SaveEditHeader)
    func saveEditHeaderEditAction(_ saveEditHeader: SaveEditHeader)
}

@objc final class SaveEditHeader: UIView {
    @objc let saveLabel = UILabel()
    @objc let countLabel = UILabel()
    @objc let deleteLabel = UILabel()
    @objc let saveDeleteButton = UIButton(type: .custom)
    @objc let editLabel = UILabel()
    @objc let editButton = UIButton(type: .custom)
    
    private var saveType: String
    private var countType: String

    @objc var delegate: SaveEditHeaderDelegate?
    @objc private(set) var isEditing = false
    
    @objc var count = 0 {
        didSet {
            countLabel.text = "\(count) \(countType.pluralize(count))"
        }
    }
    
    @objc var selectedCount = 0 {
        didSet {
            if selectedCount == 0 {
                deleteLabel.text = "Clear \(saveType)"
            } else {
                deleteLabel.text = "Remove \(selectedCount) \(countType.pluralize(selectedCount))"
            }
        }
    }
    
    @objc convenience init(saveType: String, countType: String) {
        self.init(saveType: saveType, countType: countType, delegate: nil)
    }
        
    @objc init(saveType: String, countType: String, delegate: SaveEditHeaderDelegate?) {
        self.saveType = saveType
        self.countType = countType
        self.delegate = delegate
        super.init(frame: .zero)

        saveLabel.textColor = .label
        saveLabel.textAlignment = .center
        saveLabel.font = .boldSystemFont(ofSize: 22)
        saveLabel.text = "Save \(saveType.capitalized)"
        addSubview(saveLabel)
        saveLabel.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(0.75)
            make.height.equalToSuperview().multipliedBy(0.666)
            make.leading.top.equalToSuperview()
        }

        countLabel.textColor = .label
        countLabel.textAlignment = .center
        countLabel.font = .boldSystemFont(ofSize: 12)
        addSubview(countLabel)
        countLabel.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(0.75)
            make.height.equalToSuperview().multipliedBy(0.333)
            make.leading.equalToSuperview()
            make.bottom.equalToSuperview().offset(-4)
        }

        deleteLabel.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.5)
        deleteLabel.textColor = .label
        deleteLabel.textAlignment = .center
        deleteLabel.font = .boldSystemFont(ofSize: 22)
        deleteLabel.adjustsFontSizeToFitWidth = true
        deleteLabel.minimumScaleFactor = 0.5
        deleteLabel.isHidden = true
        addSubview(deleteLabel)
        deleteLabel.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(0.75)
            make.leading.top.bottom.equalToSuperview()
        }

        saveDeleteButton.addTarget(self, action: #selector(saveDeleteAction(button:)), for: .touchUpInside)
        addSubview(saveDeleteButton)
        saveDeleteButton.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(0.75)
            make.leading.top.bottom.equalToSuperview()
        }

        editLabel.textColor = .systemBlue
        editLabel.textAlignment = .center
        editLabel.font = .boldSystemFont(ofSize: 22)
        editLabel.text = "Edit"
        addSubview(editLabel)
        editLabel.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(0.25)
            make.trailing.top.bottom.equalToSuperview()
        }

        editButton.addTarget(self, action: #selector(editAction(button:)), for: .touchUpInside)
        addSubview(editButton)
        editButton.snp.makeConstraints { make in
            make.width.equalToSuperview().multipliedBy(0.25)
            make.trailing.top.bottom.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }

    @objc private func saveDeleteAction(button: UIButton) {
        delegate?.saveEditHeaderSaveDeleteAction(self)
    }

    @objc private func editAction(button: UIButton) {
        delegate?.saveEditHeaderEditAction(self)
    }
    
    @objc func setEditing(_ editing: Bool, animated: Bool) {
        guard isEditing != editing else { return }
        
        isEditing = editing
        if editing {
            editLabel.backgroundColor = UIColor(red: 0.008, green: 0.46, blue: 0.933, alpha: 1)
            editLabel.textColor = .label
            editLabel.text = "Done"
        } else {
            editLabel.backgroundColor = .clear
            editLabel.textColor = .systemBlue
            editLabel.text = "Edit"
        }
        
        saveLabel.isHidden = editing
        countLabel.isHidden = editing
        deleteLabel.isHidden = !editing
    }
}
