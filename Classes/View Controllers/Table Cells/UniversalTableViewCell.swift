//
//  UniversalTableViewCell.swift
//  iSub
//
//  Created by Benjamin Baron on 11/11/20.
//  Copytrailing © 2020 Ben Baron. All trailings reserved.
//

import UIKit
import SnapKit

@objc public class UniversalTableViewCell: UITableViewCell {
    @objc static let reuseId = "UniversalTableViewCell"
    
    private var tableCellModel: TableCellModel?
    
    private let headerLabel = UILabel()
    private let cachedIndicator = CellCachedIndicatorView()
    private let numberLabel = UILabel()
    private let coverArtView = AsynchronousImageView()
    private let primaryLabel = AutoScrollingLabel()
    private let secondaryLabel = AutoScrollingLabel()
    private let durationLabel = UILabel()
    
    @objc var number: Int = 0 {
        didSet { numberLabel.text = "\(number)" }
    }
    
    @objc var headerText: String = "" {
        didSet { headerLabel.text = headerText }
    }
    
    @objc var hideHeaderLabel: Bool = true {
        didSet { if oldValue != hideNumberLabel { makeHeaderLabelConstraints() } }
    }
    
    @objc var hideNumberLabel: Bool = false {
        didSet { if oldValue != hideNumberLabel { makeNumberLabelConstraints() } }
    }
    
    @objc var hideCoverArt: Bool = false {
        didSet { if oldValue != hideCoverArt { makeCoverArtConstraints() } }
    }
    
    @objc var hideSecondaryLabel: Bool = false {
        didSet { if oldValue != hideSecondaryLabel { makeSecondaryLabelConstraints() } }
    }
    
    @objc var hideDurationLabel: Bool = false {
        didSet { if oldValue != hideDurationLabel { makeDurationLabelConstraints() } }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        headerLabel.textColor = .label
        headerLabel.backgroundColor = .systemGray
        headerLabel.font = .systemFont(ofSize: 12)
        headerLabel.adjustsFontSizeToFitWidth = true;
        headerLabel.minimumScaleFactor = 0.5
        headerLabel.textAlignment = .center;
        contentView.addSubview(headerLabel)
                
        numberLabel.textColor = .label
        numberLabel.font = .boldSystemFont(ofSize: 24)
        numberLabel.adjustsFontSizeToFitWidth = true
        numberLabel.minimumScaleFactor = 0.25
        numberLabel.textAlignment = .center
        contentView.addSubview(numberLabel)
        
        coverArtView.isLarge = false
        coverArtView.backgroundColor = .systemGray
        contentView.addSubview(coverArtView)
        
        primaryLabel.textColor = .label
        primaryLabel.font = .boldSystemFont(ofSize: 20)
        contentView.addSubview(primaryLabel)
        
        secondaryLabel.textColor = .secondaryLabel
        secondaryLabel.font = .systemFont(ofSize: 16)
        contentView.addSubview(secondaryLabel)
        
        durationLabel.textColor = .secondaryLabel
        durationLabel.font = .systemFont(ofSize: 16)
        durationLabel.adjustsFontSizeToFitWidth = true
        durationLabel.minimumScaleFactor = 0.25
        durationLabel.textAlignment = .center
        contentView.addSubview(durationLabel)
        
        // TODO: Flip for RTL
        cachedIndicator.isHidden = true
        contentView.addSubview(cachedIndicator)
        cachedIndicator.snp.makeConstraints { make in
            make.leading.equalTo(contentView)
            make.top.equalTo(contentView)
        }
        
        makeHeaderLabelConstraints()
        makeNumberLabelConstraints()
        makeCoverArtConstraints()
        makePrimaryLabelConstraints()
        makeSecondaryLabelConstraints()
        makeDurationLabelConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("unimplemented")
    }
    
    @objc func update(model: TableCellModel) {
        tableCellModel = model;
        if !hideCoverArt { coverArtView.coverArtId = model.coverArtId }
        primaryLabel.text = model.primaryLabelText
        if !hideSecondaryLabel { secondaryLabel.text = model.secondaryLabelText }
        if !hideDurationLabel { durationLabel.text = model.durationLabelText }
    }
    
    @objc func update(primaryText: String, secondaryText: String?) {
        tableCellModel = nil;
        hideNumberLabel = true
        hideCoverArt = true
        hideSecondaryLabel = (secondaryText == nil)
        hideDurationLabel = true
        primaryLabel.text = primaryText
        secondaryLabel.text = secondaryText;
    }
    
    // MARK: AutoLayout
    
    private func makeHeaderLabelConstraints() {
        headerLabel.snp.remakeConstraints { make in
            if hideHeaderLabel { make.height.equalTo(0) }
            else { make.height.equalTo(20)}
            make.leading.equalTo(contentView)
            make.trailing.equalTo(contentView)
            make.top.equalTo(contentView)
        }
    }
    
    private func makeNumberLabelConstraints() {
        numberLabel.snp.remakeConstraints { make in
            if hideNumberLabel { make.width.equalTo(0) }
            else { make.width.equalTo(numberLabel.snp.height).multipliedBy(0.75) }
            make.leading.equalTo(contentView)
            make.top.equalTo(headerLabel.snp.bottom)
            make.bottom.equalTo(contentView)
        }
    }
    
    private func makeCoverArtConstraints() {
        coverArtView.snp.remakeConstraints { make in
            if hideCoverArt { make.width.equalTo(0) }
            else { make.width.equalTo(coverArtView.snp.height) }
            make.leading.equalTo(numberLabel.snp.trailing)
            make.top.equalTo(headerLabel.snp.bottom)
            make.bottom.equalTo(contentView)
        }
    }
    
    private func makePrimaryLabelConstraints() {
        primaryLabel.snp.remakeConstraints { make in
            make.leading.equalTo(coverArtView.snp.trailing).offset(hideCoverArt ? 0 : 5)
            make.trailing.equalTo(durationLabel.snp.leading).offset(-5)
            make.top.equalTo(headerLabel.snp.bottom)
            make.bottom.equalTo(secondaryLabel.snp.top)
        }
    }
    
    private func makeSecondaryLabelConstraints() {
        secondaryLabel.snp.remakeConstraints { make in
            if hideSecondaryLabel { make.height.equalTo(0) }
            else { make.height.equalTo(contentView).multipliedBy(0.33) }
            make.leading.equalTo(primaryLabel)
            make.trailing.equalTo(primaryLabel)
            make.top.equalTo(primaryLabel.snp.bottom)
            make.bottom.equalTo(contentView)
        }
    }
    
    private func makeDurationLabelConstraints() {
        durationLabel.snp.remakeConstraints { make in
            if hideDurationLabel { make.width.equalTo(0) }
            else { make.width.equalTo(durationLabel.snp.height).multipliedBy(0.75) }
            make.trailing.equalTo(contentView).offset(hideDurationLabel ? 0 : -5)
            make.top.equalTo(headerLabel.snp.bottom)
            make.bottom.equalTo(contentView)
        }
    }
}
