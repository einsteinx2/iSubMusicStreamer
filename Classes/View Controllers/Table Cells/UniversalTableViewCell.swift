//
//  UniversalTableViewCell.swift
//  iSub
//
//  Created by Benjamin Baron on 11/11/20.
//  Copytrailing © 2020 Ben Baron. All trailings reserved.
//

import UIKit
import SnapKit

final class UniversalTableViewCell: UITableViewCell {
    static let reuseId = "UniversalTableViewCell"
    
    private var tableCellModel: TableCellModel?
    
    private let headerLabel = UILabel()
    private let downloadedIndicator = DownloadedIndicatorView()
    private let numberLabel = UILabel()
    private let coverArtView = AsyncImageView()
    private let primaryLabel = UILabel()
    private let secondaryLabel = UILabel()
    private let durationLabel = UILabel()
    
//    var autoScroll: Bool {
//        get { return primaryLabel.autoScroll }
//        set {
//            primaryLabel.autoScroll = newValue
//            secondaryLabel.autoScroll = newValue
//        }
//    }
//    
//    var repeatScroll: Bool {
//        get { return primaryLabel.repeatScroll }
//        set {
//            primaryLabel.repeatScroll = newValue
//            secondaryLabel.repeatScroll = newValue
//        }
//    }
    
    var number: Int = 0 {
        didSet { numberLabel.text = "\(number)" }
    }
    var headerText: String = "" {
        didSet { headerLabel.text = headerText }
    }
    var hideDownloadIndicator: Bool = true {
        didSet { downloadedIndicator.isHidden = (hideDownloadIndicator || !(tableCellModel?.isDownloaded ?? false)) }
    }
    var hideHeaderLabel: Bool = true {
        didSet { if oldValue != hideHeaderLabel { makeHeaderLabelConstraints() } }
    }
    var hideNumberLabel: Bool = true {
        didSet { if oldValue != hideNumberLabel { makeNumberLabelConstraints() } }
    }
    var hideCoverArt: Bool = true {
        didSet { if oldValue != hideCoverArt { makeCoverArtConstraints(); makePrimaryLabelConstraints() } }
    }
    var hideSecondaryLabel: Bool = true {
        didSet { if oldValue != hideSecondaryLabel { makeSecondaryLabelConstraints() } }
    }
    var hideDurationLabel: Bool = true {
        didSet { if oldValue != hideDurationLabel { makeDurationLabelConstraints() } }
    }
    
    func show(downloaded: Bool, number: Bool, art: Bool, secondary: Bool, duration: Bool, header: Bool = false) {
        hideDownloadIndicator = !downloaded
        hideNumberLabel = !number
        hideCoverArt = !art
        hideSecondaryLabel = !secondary
        hideDurationLabel = !duration
        hideHeaderLabel = !header
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
        primaryLabel.font = .boldSystemFont(ofSize: UIDevice.isSmall ? 16 : 17)
        contentView.addSubview(primaryLabel)
        
        secondaryLabel.textColor = .secondaryLabel
        secondaryLabel.font = .systemFont(ofSize: UIDevice.isSmall ? 13 : 14)
        contentView.addSubview(secondaryLabel)
        
        durationLabel.textColor = .secondaryLabel
        durationLabel.font = .systemFont(ofSize: 14)
        durationLabel.adjustsFontSizeToFitWidth = true
        durationLabel.minimumScaleFactor = 0.25
        durationLabel.textAlignment = .center
        contentView.addSubview(durationLabel)
        
        // TODO: Flip for RTL
        downloadedIndicator.isHidden = true
        contentView.addSubview(downloadedIndicator)
        downloadedIndicator.snp.makeConstraints { make in
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
    
    func update(model: TableCellModel?) {
        tableCellModel = model;
        if let model {
            updateCoverArtView(hideCoverArt: hideCoverArt, serverId: model.serverId, coverArtId: model.coverArtId)
            primaryLabel.text = model.primaryLabelText
            if !hideSecondaryLabel { secondaryLabel.text = model.secondaryLabelText }
            if !hideDurationLabel { durationLabel.text = model.durationLabelText }
            downloadedIndicator.isHidden = hideDownloadIndicator || !model.isDownloaded
        }
    }
    
    func update(primaryText: String, secondaryText: String? = nil, serverId: Int? = nil, coverArtId: String? = nil) {
        tableCellModel = nil
        
        hideNumberLabel = true
        hideSecondaryLabel = (secondaryText == nil)
        hideDurationLabel = true
        hideCoverArt = (serverId == nil || coverArtId == nil)
        
        primaryLabel.text = primaryText
        secondaryLabel.text = secondaryText
        updateCoverArtView(hideCoverArt: hideCoverArt, serverId: serverId, coverArtId: coverArtId)
    }
    
    private func updateCoverArtView(hideCoverArt: Bool, serverId: Int?, coverArtId: String? = nil) {
        if hideCoverArt {
            coverArtView.reset()
        } else {
            coverArtView.setIdsAndLoad(serverId: serverId, coverArtId: coverArtId)
        }
    }
    
//    func startScrollingLabels() {
//        primaryLabel.startScrolling()
//        if !hideSecondaryLabel {
//            secondaryLabel.startScrolling()
//        }
//    }
//
//    func stopScrollingLabels() {
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
                make.height.equalTo(coverArtView).multipliedBy(0.5)
            } else {
                make.bottom.equalTo(secondaryLabel.snp.top)
            }
            make.leading.equalTo(coverArtView.snp.trailing).offset(10)
            make.trailing.equalTo(durationLabel.snp.leading).offset(-10)
            make.top.equalTo(headerLabel.snp.bottom).offset(UIDevice.isSmall ? 5 : 10)
        }
    }
    
    private func makeSecondaryLabelConstraints() {
        secondaryLabel.snp.remakeConstraints { make in
            if hideSecondaryLabel { make.height.equalTo(0) }
            else { make.height.equalTo(coverArtView).multipliedBy(0.25) }
            make.leading.equalTo(primaryLabel)
            make.trailing.equalTo(primaryLabel)
            make.bottom.equalToSuperview().offset(UIDevice.isSmall ? -5 : -10)
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
