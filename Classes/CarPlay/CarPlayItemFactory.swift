//
//  CarPlayItemFactory.swift
//  iSub
//
//  Created by Ben Baron on 7/18/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import CarPlay
import Resolver

// Snapshot of the head unit's runtime list limits, referenced from screen code so
// screens can bound their row hydration without importing CarPlay themselves
enum CarPlayLimits {
    static var maximumItemCount: Int { CPListTemplate.maximumItemCount }
    static var maximumSectionCount: Int { CPListTemplate.maximumSectionCount }
}

// Maps CP-free row models to CarPlay list objects. Owns the three CarPlay-specific
// invariants: every CPListItem handler calls its completion (or the car UI spins
// forever), section/item counts stay under the head unit's runtime limits, and
// images are re-rendered for the car display's scale (stored thumbs are sized for
// the phone's screen).
final class CarPlayItemFactory {
    // Receives the row's action and the CPListItem completion; the handler owns
    // calling the completion when the action settles
    typealias ActionHandler = (CarPlayRowAction, @escaping () -> Void) -> Void

    @Injected private var settings: SavedSettings

    private let traitCollection: UITraitCollection
    private let coverArtManager: AsyncCoverArtLoaderManager
    private let actionHandler: ActionHandler

    // Cap async art downloads per template build so giant lists don't spawn
    // hundreds of network tasks; rows past the budget still show cached art
    private static let artDownloadBudget = 50

    init(traitCollection: UITraitCollection, coverArtManager: AsyncCoverArtLoaderManager = .shared, actionHandler: @escaping ActionHandler) {
        self.traitCollection = traitCollection
        self.coverArtManager = coverArtManager
        self.actionHandler = actionHandler
    }

    // MARK: Section building

    func listSections(_ sections: [CarPlaySection]) -> [CPListSection] {
        let (clamped, truncatedCount) = Self.clamped(sections: sections,
                                                     maxSections: CPListTemplate.maximumSectionCount,
                                                     maxItems: CPListTemplate.maximumItemCount)
        var downloadsRemaining = Self.artDownloadBudget
        var listSections = clamped.map { section in
            CPListSection(items: section.rows.map { listItem(for: $0, downloadsRemaining: &downloadsRemaining) },
                          header: section.header,
                          sectionIndexTitle: section.indexTitle)
        }
        if truncatedCount > 0 {
            let keptCount = clamped.reduce(0) { $0 + $1.rows.count }
            let note = CPListItem(text: "Showing the first \(keptCount) items", detailText: nil)
            note.isEnabled = false
            note.handler = { _, completion in completion() }
            listSections.append(CPListSection(items: [note]))
        }
        return listSections
    }

    // Pure so the truncation math is unit testable. Reserves one item for the
    // "Showing the first N" note row whenever anything is dropped.
    static func clamped(sections: [CarPlaySection], maxSections: Int, maxItems: Int) -> (sections: [CarPlaySection], truncatedCount: Int) {
        let totalItems = sections.reduce(0) { $0 + $1.rows.count }
        guard totalItems > maxItems || sections.count > maxSections else { return (sections, 0) }

        // Reserve room for the note row (its own section, its own item)
        let itemBudget = max(0, maxItems - 1)
        let sectionBudget = max(0, maxSections - 1)
        var remaining = itemBudget
        var clamped = [CarPlaySection]()
        for section in sections.prefix(sectionBudget) {
            guard remaining > 0 else { break }
            let rows = Array(section.rows.prefix(remaining))
            remaining -= rows.count
            if !rows.isEmpty {
                clamped.append(CarPlaySection(header: section.header, indexTitle: section.indexTitle, rows: rows))
            }
        }
        let keptItems = clamped.reduce(0) { $0 + $1.rows.count }
        return (clamped, totalItems - keptItems)
    }

    // MARK: Item building

    private func listItem(for row: CarPlayRow, downloadsRemaining: inout Int) -> CPListItem {
        let item = CPListItem(text: row.title, detailText: row.subtitle)
        item.isEnabled = row.isEnabled
        item.accessoryType = row.showsDisclosure ? .disclosureIndicator : .none
        if row.isPlaying {
            item.playingIndicatorLocation = .trailing
            item.isPlaying = true
        }

        let action = row.action
        let actionHandler = self.actionHandler
        item.handler = { _, completion in
            actionHandler(action, completion)
        }

        if let artId = row.artId {
            item.setImage(renderedForCar(coverArtManager.coverArtImage(serverId: artId.serverId, coverArtId: artId.coverArtId, isLarge: false)))
            let isCached = coverArtManager.isCached(serverId: artId.serverId, coverArtId: artId.coverArtId, isLarge: false)
            if !isCached && !settings.isOfflineMode && downloadsRemaining > 0 {
                downloadsRemaining -= 1
                startArtDownload(artId: artId, item: item)
            }
        } else if row.showsDefaultArt {
            item.setImage(renderedForCar(AsyncCoverArtLoaderManager.defaultCoverArtImage(isLarge: false)))
        }

        return item
    }

    private func startArtDownload(artId: CoverArtLoadingId, item: CPListItem) {
        let coverArtManager = self.coverArtManager
        Task { [weak item] in
            guard let coverArt = await coverArtManager.download(serverId: artId.serverId, coverArtId: artId.coverArtId, isLarge: false), let image = coverArt.image else { return }
            let rendered = self.renderedForCar(image)
            await MainActor.run {
                item?.setImage(rendered)
            }
        }
    }

    // Stored small art is sized for the phone screen; render it at the car
    // display's scale and CPListItem's maximum size so head units get sharp,
    // right-sized bitmaps. Never upscales.
    func renderedForCar(_ image: UIImage?) -> UIImage? {
        guard let image, image.size.width > 0, image.size.height > 0 else { return nil }
        let maxSize = CPListItem.maximumImageSize
        let fitScale = min(maxSize.width / image.size.width, maxSize.height / image.size.height, 1)
        let fitSize = CGSize(width: image.size.width * fitScale, height: image.size.height * fitScale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 2
        return UIGraphicsImageRenderer(size: fitSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: fitSize))
        }
    }
}
