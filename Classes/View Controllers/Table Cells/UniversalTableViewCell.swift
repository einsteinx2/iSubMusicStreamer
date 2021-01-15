//
//  UniversalTableViewCell.swift
//  iSub
//
//  Created by Benjamin Baron on 11/11/20.
//  Copytrailing © 2020 Ben Baron. All trailings reserved.
//

import UIKit
import SnapKit

@objc final class UniversalTableViewCell: UITableViewCell {
    @objc static let reuseId = "UniversalTableViewCell"
    
    private var tableCellModel: TableCellModel?
    
    private let headerLabel = UILabel()
    private let cachedIndicator = CellCachedIndicatorView()
    private let numberLabel = UILabel()
    private let coverArtView = AsyncImageView()
    private let primaryLabel = UILabel()
    private let secondaryLabel = UILabel()
    private let durationLabel = UILabel()
    
//    @objc var autoScroll: Bool {
//        get { return primaryLabel.autoScroll }
//        set {
//            primaryLabel.autoScroll = newValue
//            secondaryLabel.autoScroll = newValue
//        }
//    }
//    
//    @objc var repeatScroll: Bool {
//        get { return primaryLabel.repeatScroll }
//        set {
//            primaryLabel.repeatScroll = newValue
//            secondaryLabel.repeatScroll = newValue
//        }
//    }
    
    @objc var number: Int = 0 {
        didSet { numberLabel.text = "\(number)" }
    }
    
    @objc var headerText: String = "" {
        didSet { headerLabel.text = headerText }
    }
    
    @objc var hideCacheIndicator: Bool = true {
        didSet { cachedIndicator.isHidden = (hideCacheIndicator || !(tableCellModel?.isCached ?? false)) }
    }
    
    @objc var hideHeaderLabel: Bool = true {
        didSet { if oldValue != hideHeaderLabel { makeHeaderLabelConstraints() } }
    }
    
    @objc var hideNumberLabel: Bool = true {
        didSet { if oldValue != hideNumberLabel { makeNumberLabelConstraints() } }
    }
    
    @objc var hideCoverArt: Bool = true {
        didSet { if oldValue != hideCoverArt { makeCoverArtConstraints(); makePrimaryLabelConstraints() } }
    }
    
    @objc var hideSecondaryLabel: Bool = true {
        didSet { if oldValue != hideSecondaryLabel { makeSecondaryLabelConstraints() } }
    }
    
    @objc var hideDurationLabel: Bool = true {
        didSet { if oldValue != hideDurationLabel { makeDurationLabelConstraints() } }
    }
    
    @objc(showCached:number:art:secondary:duration:)
    func show(cached: Bool, number: Bool, art: Bool, secondary: Bool, duration: Bool) {
        hideCacheIndicator = !cached
        hideNumberLabel = !number
        hideCoverArt = !art
        hideSecondaryLabel = !secondary
        hideDurationLabel = !duration
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        backgroundColor = .systemBackground
        
        headerLabel.textColor = .label
        headerLabel.backgroundColor = .systemGray
        headerLabel.font = .systemFont(ofSize: 12)
        headerLabel.adjustsFontSizeToFitWidth = true;
        headerLabel.minimumScaleFactor = 0.5
        headerLabel.textAlignment = .center;
        contentView.addSubview(headerLabel)
                
        numberLabel.textColor = .label
        numberLabel.font = .boldSystemFont(ofSize: 20)
        numberLabel.adjustsFontSizeToFitWidth = true
        numberLabel.minimumScaleFactor = 0.25
        numberLabel.textAlignment = .center
        contentView.addSubview(numberLabel)
        
        coverArtView.isLarge = false
        coverArtView.backgroundColor = .systemGray
        contentView.addSubview(coverArtView)
        
        primaryLabel.textColor = .label
        primaryLabel.font = .boldSystemFont(ofSize: UIDevice.isSmall() ? 16 : 17)
        contentView.addSubview(primaryLabel)
        
        secondaryLabel.textColor = .secondaryLabel
        secondaryLabel.font = .systemFont(ofSize: UIDevice.isSmall() ? 13 : 14)
        contentView.addSubview(secondaryLabel)
        
        durationLabel.textColor = .secondaryLabel
        durationLabel.font = .systemFont(ofSize: 14)
        durationLabel.adjustsFontSizeToFitWidth = true
        durationLabel.minimumScaleFactor = 0.25
        durationLabel.textAlignment = .center
        contentView.addSubview(durationLabel)
        
        // TODO: Flip for RTL
        cachedIndicator.isHidden = true
        contentView.addSubview(cachedIndicator)
        cachedIndicator.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalTo(headerLabel.snp.bottom)
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
    
    @objc func update(model: TableCellModel?) {
        tableCellModel = model;
        if let model = model {
            if !hideCoverArt { coverArtView.coverArtId = model.coverArtId }
            primaryLabel.text = model.primaryLabelText
            if !hideSecondaryLabel { secondaryLabel.text = model.secondaryLabelText }
            if !hideDurationLabel { durationLabel.text = model.durationLabelText }
            cachedIndicator.isHidden = hideCacheIndicator || !model.isCached
        }
    }
    
    @objc func update(primaryText: String, secondaryText: String?) {
        tableCellModel = nil;
        hideNumberLabel = true
        hideCoverArt = true
        hideSecondaryLabel = (secondaryText == nil)
        hideDurationLabel = true
        primaryLabel.text = primaryText
        secondaryLabel.text = secondaryText;
        cachedIndicator.isHidden = true;
    }
    
    @objc func update(primaryText: String, secondaryText: String?, coverArtId: String?) {
        tableCellModel = nil;
        hideNumberLabel = true
        hideSecondaryLabel = (secondaryText == nil)
        hideDurationLabel = true
        primaryLabel.text = primaryText
        secondaryLabel.text = secondaryText;
        coverArtView.coverArtId = coverArtId;
        cachedIndicator.isHidden = true;
    }
    
//    @objc func startScrollingLabels() {
//        primaryLabel.startScrolling()
//        if !hideSecondaryLabel {
//            secondaryLabel.startScrolling()
//        }
//    }
//
//    @objc func stopScrollingLabels() {
//        primaryLabel.stopScrolling()
//        if !hideSecondaryLabel {
//            secondaryLabel.stopScrolling()
//        }
//    }
    
    // MARK: AutoLayout
    
    private func makeHeaderLabelConstraints() {
        headerLabel.snp.remakeConstraints { make in
            if hideHeaderLabel { make.height.equalTo(0) }
            else { make.height.equalTo(20)}
            make.leading.trailing.top.equalToSuperview()
        }
    }
    
    private func makeNumberLabelConstraints() {
        numberLabel.snp.remakeConstraints { make in
            if hideNumberLabel { make.width.equalTo(0) }
            else { make.width.equalTo(30) }
            make.leading.bottom.equalToSuperview()
            make.top.equalTo(headerLabel.snp.bottom)
        }
    }
    
    private func makeCoverArtConstraints() {
        coverArtView.snp.remakeConstraints { make in
            if hideCoverArt { make.width.equalTo(0) }
            else { make.width.equalTo(coverArtView.snp.height) }
            make.leading.equalTo(numberLabel.snp.trailing).offset(hideCoverArt ? 0 : 5)
            make.top.equalTo(headerLabel.snp.bottom).offset(5)
            make.bottom.equalToSuperview().offset(-5)
        }
    }
    
    private func makePrimaryLabelConstraints() {
        primaryLabel.snp.remakeConstraints { make in
            if hideSecondaryLabel {
                make.height.equalTo(coverArtView).multipliedBy(0.66)
            } else {
                make.bottom.equalTo(secondaryLabel.snp.top)
            }
            make.leading.equalTo(coverArtView.snp.trailing).offset(10)
            make.trailing.equalTo(durationLabel.snp.leading).offset(-10)
            make.top.equalTo(headerLabel.snp.bottom).offset(UIDevice.isSmall() ? 5 : 10)
        }
    }
    
    private func makeSecondaryLabelConstraints() {
        secondaryLabel.snp.remakeConstraints { make in
            if hideSecondaryLabel { make.height.equalTo(0) }
            else { make.height.equalTo(coverArtView).multipliedBy(0.33) }
            make.leading.equalTo(primaryLabel)
            make.trailing.equalTo(primaryLabel)
            make.bottom.equalToSuperview().offset(UIDevice.isSmall() ? -5 : -10)
        }
    }
    
    private func makeDurationLabelConstraints() {
        durationLabel.snp.remakeConstraints { make in
            if hideDurationLabel { make.width.equalTo(0) }
            else { make.width.equalTo(30) }
            make.trailing.equalToSuperview().offset(hideDurationLabel ? 0 : -10)
            make.top.equalTo(headerLabel.snp.bottom)
            make.bottom.equalToSuperview()
        }
    }
}
