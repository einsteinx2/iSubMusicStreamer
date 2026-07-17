//
//  SavePlaylistFlow.swift
//  iSub
//
//  Created by Ben Baron on 7/10/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit
import Resolver

// Save-playlist flow shared by the Play Queue and Local Playlists tabs and the local
// playlist detail screen: prompts for a location (local vs server) and a name, saves the
// play queue as a local playlist, or uploads songs to the server via createPlaylist —
// asking to overwrite when a playlist with the same name already exists.
@MainActor
final class SavePlaylistFlow {
    @Injected private var store: Store
    @Injected private var settings: SavedSettings
    @Injected private var playQueue: PlayQueue

    private weak var viewController: UIViewController?
    private var uploadTask: Task<Void, Never>?

    init(viewController: UIViewController) {
        self.viewController = viewController
    }

    func cancel() {
        uploadTask?.cancel()
        uploadTask = nil
    }

    // MARK: Play queue

    // Entry point for the Play Queue and Local Playlists tabs' save button
    func promptToSavePlayQueue() {
        guard let viewController else { return }

        if settings.isOfflineMode {
            promptForPlaylistName(isLocal: true)
        } else {
            let message = "Would you like to save this playlist to your device or to your Subsonic server?"
            let alert = UIAlertController(title: "Playlist Location", message: message, preferredStyle: .alert)
            alert.addAction(title: "Local", style: .default) { _ in
                self.promptForPlaylistName(isLocal: true)
            }
            alert.addAction(title: "Server", style: .default) { _ in
                self.promptForPlaylistName(isLocal: false)
            }
            alert.addCancelAction()
            viewController.present(alert, animated: true)
        }
    }

    private func promptForPlaylistName(isLocal: Bool) {
        guard let viewController else { return }

        let alert = UIAlertController(title: "Save Playlist", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Playlist name"
        }
        alert.addAction(title: "Save", style: .default) { _ in
            guard let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            if isLocal {
                self.savePlayQueueLocally(name: name)
            } else {
                self.uploadPlayQueue(name: name)
            }
        }
        alert.addCancelAction()
        viewController.present(alert, animated: true)
    }

    // MARK: Local save

    private func savePlayQueueLocally(name: String) {
        if let existing = store.localPlaylist(name: name) {
            // A playlist with this name already exists, so ask before replacing its songs
            Task {
                guard await confirmOverwrite(name: name) else { return }
                savePlayQueueLocally(overwriting: existing)
            }
        } else {
            savePlayQueueLocally(newPlaylistNamed: name)
        }
    }

    private func savePlayQueueLocally(newPlaylistNamed name: String) {
        // Snapshot the queue on the main actor before hopping off it: the background
        // block used to read the live playQueue while the main thread could mutate it
        // mid-copy (song advance, shuffle, jukebox refresh), saving a truncated or
        // reordered playlist
        let songs = playQueueSongsSnapshot()
        let contextId = settings.currentServerId
        let store = self.store
        HUD.show()
        DispatchQueue.userInitiated.async {
            defer { HUD.hide() }
            guard let nextLocalPlaylistId = store.nextLocalPlaylistId,
                  store.add(localPlaylist: LocalPlaylist(id: nextLocalPlaylistId, name: name, contextId: contextId)),
                  Self.copy(songs: songs, localPlaylistId: nextLocalPlaylistId, store: store) else {
                Task { @MainActor in self.presentLocalSaveError() }
                return
            }
        }
    }

    private func savePlayQueueLocally(overwriting localPlaylist: LocalPlaylist) {
        let songs = playQueueSongsSnapshot()
        let store = self.store
        HUD.show()
        DispatchQueue.userInitiated.async {
            defer { HUD.hide() }
            guard store.clear(localPlaylistId: localPlaylist.id),
                  Self.copy(songs: songs, localPlaylistId: localPlaylist.id, store: store) else {
                Task { @MainActor in self.presentLocalSaveError() }
                return
            }
        }
    }

    private func playQueueSongsSnapshot() -> [Song] {
        (0..<playQueue.count).compactMap { playQueue.song(index: $0) }
    }

    // TODO: optimize this in the store to not require a write per song
    private nonisolated static func copy(songs: [Song], localPlaylistId: Int, store: Store) -> Bool {
        for song in songs {
            guard store.add(song: song, localPlaylistId: localPlaylistId) else { return false }
        }
        return true
    }

    private func presentLocalSaveError() {
        DispatchQueue.main.async {
            guard self.settings.isPopupsEnabled, let viewController = self.viewController else { return }
            let alert = UIAlertController(title: "Error", message: "There was an error saving the playlist.", preferredStyle: .alert)
            alert.addOKAction()
            viewController.present(alert, animated: true)
        }
    }

    // MARK: Server upload

    // Uploads the current play queue, honoring shuffle and jukebox mode
    // (currentPlaylistId resolves to the shuffle/jukebox queue as appropriate)
    private func uploadPlayQueue(name: String) {
        let serverId = settings.currentServerId
        let songIds = store.songIds(localPlaylistId: playQueue.currentPlaylistId, serverId: serverId)
        upload(name: name, songIds: songIds, serverId: serverId)
    }

    // Uploads an ordered song list as a named server playlist, confirming before
    // overwriting an existing playlist with the same name (also the entry point for
    // the local playlist detail screen's "Save to Server" button)
    func upload(name: String, songIds: [String], serverId: Int) {
        uploadTask?.cancel()
        uploadTask = Task {
            defer { HUD.hide() }
            do {
                HUD.show(closeHandler: cancel)

                // Refresh the server playlists so the name-collision check sees the server's current state
                let serverPlaylists = try await AsyncServerPlaylistsLoader(serverId: serverId).load()
                var overwriteServerPlaylistId: Int?
                if let existing = serverPlaylists.first(where: { $0.name == name }) {
                    HUD.hide()
                    guard await confirmOverwrite(name: name) else { return }
                    HUD.show(closeHandler: cancel)
                    overwriteServerPlaylistId = existing.id
                }

                try Task.checkCancellation()
                try await AsyncServerPlaylistCreateLoader(serverId: serverId,
                                                          name: name,
                                                          overwriteServerPlaylistId: overwriteServerPlaylistId,
                                                          songIds: songIds).load()

                // Refresh the cached server playlists so the Server tab shows the
                // result. The save has already succeeded at this point, so a failed
                // refresh must not fall into the catch and report a save error
                _ = try? await AsyncServerPlaylistsLoader(serverId: serverId).load()
            } catch {
                if settings.isPopupsEnabled && !error.isCanceled, let viewController {
                    let message = "There was an error saving the playlist to the server.\n\nError: \(error)"
                    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                    alert.addOKAction()
                    viewController.present(alert, animated: true)
                }
            }
        }
    }

    private func confirmOverwrite(name: String) async -> Bool {
        guard let viewController else { return false }
        return await withCheckedContinuation { continuation in
            let message = "A playlist named \"\(name)\" already exists. Would you like to overwrite it?"
            let alert = UIAlertController(title: "Overwrite?", message: message, preferredStyle: .alert)
            alert.addAction(title: "Overwrite", style: .destructive) { _ in
                continuation.resume(returning: true)
            }
            alert.addCancelAction { _ in
                continuation.resume(returning: false)
            }
            viewController.present(alert, animated: true)
        }
    }
}
