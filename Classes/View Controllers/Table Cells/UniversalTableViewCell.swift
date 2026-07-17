//
//  UniversalTableViewCell.swift
//  iSub
//
//  Created by Benjamin Baron on 11/11/20.
//  Copytrailing © 2020 Ben Baron. All trailings reserved.
//

import UIKit
import SnapKit

// A small tinted capsule naming the item's server in Combined Library lists.
// Collapses to nothing when it has no text, so it can sit in the constraint chain
// permanently.
private final class ServerBadgeLabel: UILabel {
    private let insets = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        guard let text, !text.isEmpty else { return .zero }
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}

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
    private let serverBadgeLabel = ServerBadgeLabel()

    // Test seam: the server badge's current text (nil outside the Combined Library)
    var serverBadgeText: String? {
        (serverBadgeLabel.text?.isEmpty ?? true) ? nil : serverBadgeLabel.text
    }
    
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
        accessibilityIdentifier = AccessibilityId.universalTableViewCell
        
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

        serverBadgeLabel.textColor = .secondaryLabel
        serverBadgeLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        serverBadgeLabel.backgroundColor = .secondarySystemFill
        serverBadgeLabel.clipsToBounds = true
        // The badge must never truncate — the primary label yields instead
        serverBadgeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        serverBadgeLabel.setContentHuggingPriority(.required, for: .horizontal)
        contentView.addSubview(serverBadgeLabel)
        
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
        makeServerBadgeConstraints()
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
            // Non-nil only while the Combined Library is active, so every list gets
            // its badges (or none) with no per-screen wiring
            updateServerBadge(MainActor.assumeIsolated { ServerLabels.shared.badgeText(serverId: model.serverId) })
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
        updateServerBadge(nil)
    }

    private func updateServerBadge(_ text: String?) {
        serverBadgeLabel.text = text
        serverBadgeLabel.invalidateIntrinsicContentSize()
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
            make.trailing.equalTo(serverBadgeLabel.snp.leading).offset(-8)
            make.top.equalTo(headerLabel.snp.bottom).offset(UIDevice.isSmall ? 5 : 10)
        }
    }

    private func makeServerBadgeConstraints() {
        // Sits between the primary label and the duration; intrinsic size collapses
        // to zero when there is no badge
        serverBadgeLabel.snp.makeConstraints { make in
            make.centerY.equalTo(primaryLabel)
            make.trailing.equalTo(durationLabel.snp.leading).offset(-10)
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
