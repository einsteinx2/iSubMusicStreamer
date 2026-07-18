//
//  CarPlayListScreen.swift
//  iSub
//
//  Created by Ben Baron on 7/18/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

// Base class for every CarPlay list screen. A screen owns no CarPlay objects: it
// builds CP-free [CarPlaySection] snapshots from synchronous Store reads and
// optionally runs an async server refresh. CarPlayManager pairs each screen with
// its CPListTemplate and re-renders on the screen's onChange callback.
//
// All methods run on the main thread (CarPlay templates require it; the Store
// reads are the same synchronous GRDB queries the phone UI performs on main).
// Not final so tests can subclass with canned sections.
class CarPlayListScreen {
    enum LoadState {
        case idle
        case loading
        case failed
    }

    // Subclass-writable so viewModel-delegate-based screens can track their loads
    var loadState: LoadState = .idle
    // Set by startLoadIfNeeded; fires on main whenever this screen's data changed
    private(set) var onChange: (() -> Void)?
    private var loadTask: Task<Void, Never>?

    init() {}

    // MARK: Subclass overrides

    var title: String { "" }

    // The screen's data rows, rebuilt from the Store on every call
    func sections() -> [CarPlaySection] { [] }

    // Shown when displaySections() is empty
    func emptyState() -> CarPlayEmptyState {
        switch loadState {
        case .loading: return CarPlayEmptyState(title: "Loading…")
        case .failed: return CarPlayEmptyState(title: "Couldn't Load", subtitle: "Check your connection, then try again")
        case .idle: return CarPlayEmptyState(title: "No Items")
        }
    }

    // Kick off an async server refresh when the cache is empty/stale
    func loadIfNeeded() {}

    // For screens whose loading isn't managed by runLoad (e.g. ArtistsViewModel)
    func onCancelLoad() {}

    // MARK: Manager surface

    final func startLoadIfNeeded(onChange: @escaping () -> Void) {
        self.onChange = onChange
        loadIfNeeded()
    }

    final func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil
        onCancelLoad()
    }

    // Data sections, or the failure rows when there is no cache to fall back on.
    // Refresh failures never clear cached rows because sections() re-reads the
    // Store, which still holds the last good data.
    final func displaySections() -> [CarPlaySection] {
        let dataSections = sections()
        guard dataSections.isEmpty, loadState == .failed else { return dataSections }
        let messageRow = CarPlayRow(title: "Couldn't load from the server", isEnabled: false, action: .custom(handler: { completion in completion() }))
        let retryRow = CarPlayRow(title: "Retry", action: .custom(handler: { [weak self] completion in
            self?.loadIfNeeded()
            self?.notifyChanged()
            completion()
        }))
        return [CarPlaySection(rows: [messageRow, retryRow])]
    }

    final func notifyChanged() {
        onChange?()
    }

    // MARK: Load helper

    // Runs an async loader body, tracking loadState and notifying on completion.
    // Cancellation is silent; only real failures flip the state to .failed.
    final func runLoad(_ body: @escaping () async throws -> Void) {
        guard loadState != .loading else { return }
        loadState = .loading
        loadTask = Task {
            var failed = false
            do {
                try await body()
            } catch {
                failed = !error.isCanceled
                if failed {
                    DDLogError("[CarPlay] \(type(of: self)) load failed: \(error)")
                }
            }
            let didFail = failed
            await MainActor.run {
                self.loadTask = nil
                self.loadState = didFail ? .failed : .idle
                self.notifyChanged()
            }
        }
    }
}

// MARK: Shared row builders

struct CarPlayRowBuilder {
    // A tappable song row; the playing indicator follows the queue's current song.
    // Screens that know the row's queue position pass isPlayingOverride so a song
    // queued twice doesn't light up both rows.
    static func songRow(song: Song, currentSong: Song?, isOfflineMode: Bool, showTrackNumber: Bool = false, isPlayingOverride: Bool? = nil, action: CarPlayRowAction) -> CarPlayRow {
        var title = song.title
        if showTrackNumber, let track = song.track, track > 0 {
            title = "\(track). \(song.title)"
        }
        let isPlaying = isPlayingOverride ?? currentSong.map { $0.serverId == song.serverId && $0.id == song.id } ?? false
        return CarPlayRow(title: title,
                          subtitle: song.tagArtistName,
                          artId: artId(serverId: song.serverId, coverArtId: song.coverArtId),
                          showsDefaultArt: true,
                          isEnabled: !isOfflineMode || song.isAvailableOffline,
                          isPlaying: isPlaying,
                          action: action)
    }

    static func artId(serverId: Int, coverArtId: String?) -> CoverArtLoadingId? {
        guard let coverArtId else { return nil }
        return CoverArtLoadingId(serverId: serverId, coverArtId: coverArtId, isLarge: false)
    }
}
