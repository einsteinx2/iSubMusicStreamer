//
//  Jukebox.swift
//  iSub
//
//  Created by Benjamin Baron on 1/19/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

// The jukebox's one seam back to the play queue (Phase 8.9), implemented by
// JukeboxPlaybackMode and attached by the PlaybackCoordinator that owns it.
// Both methods are called on the main thread.
protocol JukeboxDelegate: AnyObject {
    func jukebox(_ jukebox: Jukebox, didReportCurrentIndex index: Int)
    func jukebox(_ jukebox: Jukebox, didReceiveQueue songs: [Song])
}

// A remote-control client for the Subsonic jukebox (Phase 8.9): sends commands,
// polls status, parses responses, and reports state through JukeboxDelegate. All
// queue mirroring and mode policy lives in JukeboxPlaybackMode; all alert
// presentation lives in the UI (Notifications.jukeboxError).
final class Jukebox {
    enum ActionType: String {
        case get, status, set, start, stop, skip, add, clear, remove, shuffle, setGain
    }
    enum ParameterType: String {
        case action, index, offset, id, gain
    }

    private let settings: SavedSettings

    private weak var delegate: JukeboxDelegate?

    init(settings: SavedSettings) {
        self.settings = settings
    }

    func attach(delegate: JukeboxDelegate) {
        self.delegate = delegate
    }

    private(set) var isPlaying = false
    private(set) var currentIndex = -1
    private(set) var gain: Float = 0.0
    private(set) var position = 0
    private(set) var positionLastReportedAt = Date()

    private var serverId: Int { settings.currentServerId }

    private let sessionDelegate = SelfSignedCertURLSessionDelegate()
    private lazy var session: URLSession = {
        let configuration = APIURLSession.ephemeralConfiguration()
        configuration.httpMaximumConnectionsPerHost = 1
        return URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)
    }()

    func playSong(index: Int) {
        queueDataTask(action: .skip, parameters: [.index: index])
        delegate?.jukebox(self, didReportCurrentIndex: index)
    }

    func play() {
        queueDataTask(action: .start)
        isPlaying = true
    }

    func stop() {
        queueDataTask(action: .stop)
        isPlaying = false
    }

    func setVolume(level: Float) {
        queueDataTask(action: .setGain, parameters: [.gain: level])
    }

    func seek(seconds: Int) {
        // Subsonic supports this using the "skip" action with the "offset" parameter and reports back the seek position with the "position" attribute of "jukeboxStatus"
        queueDataTask(action: .skip, parameters: [.offset: seconds])
    }

    func add(songId: String) {
        queueDataTask(action: .add, parameters: [.id: songId])
    }

    func add(songIds: [String]) {
        if songIds.count > 0 {
            queueDataTask(action: .add, parameters: [.id: songIds])
        }
    }

    func remove(songId: String) {
        queueDataTask(action: .remove, parameters: [.id: songId])
    }

    func clearRemotePlaylist() {
        queueDataTask(action: .clear)
    }

    // Stops the periodic getInfo polling chain (used when leaving jukebox mode)
    func cancelGetInfo() {
        getInfoWorkItem?.cancel()
        getInfoWorkItem = nil
    }

    private var getInfoWorkItem: DispatchWorkItem?
    func getInfo(delay: Double = 0.5) {
        // Make sure this doesn't run a bunch of times in a row
        getInfoWorkItem?.cancel()
        let getInfoWorkItem = DispatchWorkItem {
            self.queueDataTask(action: .get)
        }
        self.getInfoWorkItem = getInfoWorkItem
        DispatchQueue.main.async(after: delay, execute: getInfoWorkItem)
    }

    private func queueDataTask(action: ActionType, parameters: [ParameterType: Any] = [:]) {
        var finalParameters: [String: Any] = [ParameterType.action.rawValue: action.rawValue]
        for (key, value) in parameters {
            finalParameters[key.rawValue] = value
        }

        guard let request = URLRequest(serverId: serverId, subsonicAction: .jukeboxControl, parameters: finalParameters) else {
            DDLogError("[Jukebox] Failed to create URLRequest with parameters \(finalParameters)")
            return
        }

        let dataTask = session.dataTask(with: request) { data, response, error in
            if let data = data, let jukeboxResponse = self.parse(data: data) {
                // The response mutates jukebox state and the (main-confined) play
                // queue via the delegate, but this callback runs on the session's
                // background queue, so apply it on the main thread
                DispatchQueue.main.async {
                    // Jukebox mode may have been left (or the server switched) while
                    // this request was in flight. Applying the response now would
                    // clobber the LOCAL play queue through the delegate and revive
                    // the polling chain that deactivate() just cancelled.
                    guard self.settings.isJukeboxEnabled else { return }

                    // These values are always returned
                    self.delegate?.jukebox(self, didReportCurrentIndex: jukeboxResponse.currentIndex)
                    self.gain = jukeboxResponse.gain
                    self.isPlaying = jukeboxResponse.isPlaying
                    self.position = jukeboxResponse.position
                    self.positionLastReportedAt = Date()

                    // Songs are only returned when calling the "get" action; the
                    // delegate mirrors them into the local queue
                    if let songs = jukeboxResponse.songs {
                        self.delegate?.jukebox(self, didReceiveQueue: songs)
                    }

                    let delay = action == .get ? 30 : 0.5
                    self.getInfo(delay: delay)
                }
            } else if let error {
                self.handleConnectionError(error: error)
            }
        }
        dataTask.resume()
    }

    private func handleConnectionError(error: Error) {
        let message = "There was an error controlling the Jukebox.\n\nError: \(error)"
        NotificationCenter.postOnMainThread(name: Notifications.jukeboxError, userInfo: ["title": "Error", "message": message])
    }

    private func parse(data: Data) -> JukeboxResponse? {
        guard let response = try? SubsonicEnvelope.decode(from: data).response else {
            let message = "There was an error controlling the Jukebox.\n\nError reading the response from Subsonic."
            NotificationCenter.postOnMainThread(name: Notifications.jukeboxError, userInfo: ["title": "Subsonic Error", "message": message])
            return nil
        }

        if let error = response.error {
            let message = error.message ?? "Unknown error"
            if error.code == 50 {
                // User is not authorized to control the jukebox. parse() runs on
                // the session's background queue and the mode state is
                // main-confined, so flip the setting on the main thread (before
                // the jukeboxDisabled observers run, since both are enqueued in
                // order)
                DispatchQueue.main.async {
                    self.settings.isJukeboxEnabled = false
                    NotificationCenter.postOnMainThread(name: Notifications.jukeboxDisabled)
                }
            }

            let alertMessage = "There was an error controlling the Jukebox.\n\nError \(error.code): \(message)"
            NotificationCenter.postOnMainThread(name: Notifications.jukeboxError, userInfo: ["title": "Subsonic Error", "message": alertMessage])
        } else if let status = response.jukeboxStatus {
            return JukeboxResponse(songs: nil,
                                   currentIndex: status.currentIndex ?? 0,
                                   isPlaying: status.playing ?? false,
                                   gain: Float(status.gain ?? 0),
                                   position: status.position ?? 0)
        } else if let playlist = response.jukeboxPlaylist {
            let songs = (playlist.entry?.values ?? []).map { Song(serverId: serverId, dto: $0) }
            return JukeboxResponse(songs: songs,
                                   currentIndex: playlist.currentIndex ?? 0,
                                   isPlaying: playlist.playing ?? false,
                                   gain: Float(playlist.gain ?? 0),
                                   position: playlist.position ?? 0)
        }
        return nil
    }
}

private struct JukeboxResponse {
    let songs: [Song]?
    let currentIndex: Int
    let isPlaying: Bool
    let gain: Float
    let position: Int // seek position
}
