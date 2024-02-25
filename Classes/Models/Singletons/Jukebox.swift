//
//  Jukebox.swift
//  iSub
//
//  Created by Benjamin Baron on 1/19/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver
import CocoaLumberjackSwift

final class Jukebox {
    enum ActionType: String {
        case get, status, set, start, stop, skip, add, clear, remove, shuffle, setGain
    }
    enum ParameterType: String {
        case action, index, offset, id, gain
    }
    
    @LazyInjected private var playQueue: PlayQueue
    @LazyInjected private var settings: SavedSettings
    
    private(set) var isPlaying = false
    private(set) var currentIndex = -1
    private(set) var gain: Float = 0.0
    private(set) var position = 0
    private(set) var positionLastReportedAt = Date()
    
    private var serverId: Int { settings.currentServerId }
    
    private let sessionDelegate = SelfSignedCertURLSessionDelegate()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpMaximumConnectionsPerHost = 1
        return URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)
    }()
    
    func playSong(index: Int) {
        queueDataTask(action: .skip, parameters: [.index: index])
        playQueue.currentIndex = index
    }
    
    func play() {
        queueDataTask(action: .start)
        isPlaying = true
    }
    
    func stop() {
        queueDataTask(action: .stop)
        isPlaying = false
    }
    
    func skipPrev() {
        let index = playQueue.prevIndex
        if index >= 0 {
            playSong(index: index)
            isPlaying = true
        }
    }
    
    func skipNext() {
        let index = playQueue.nextIndex
        if index < playQueue.count {
            playSong(index: index)
        } else {
            NotificationCenter.postOnMainThread(name: Notifications.songPlaybackEnded)
            stop()
        }
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
    
    func replacePlaylistWithLocal() {
        clearPlaylist(remoteOnly: true)
        add(songIds: playQueue.songs().filter({ $0.serverId == serverId }).map({ $0.id }))
    }
    
    func clearPlaylist(remoteOnly: Bool = false) {
        queueDataTask(action: .clear)
        if !remoteOnly {
            _ = playQueue.clear()
        }
    }
    
    func shuffle() {
        queueDataTask(action: .shuffle)
        _ = playQueue.clear()
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
        
        guard let request = URLRequest(serverId: serverId, subsonicAction: "jukeboxControl", parameters: finalParameters) else {
            DDLogError("[Jukebox] Failed to create URLRequest with parameters \(finalParameters)")
            return
        }
        
        let dataTask = session.dataTask(with: request) { data, response, error in
            if let data = data, let jukeboxResponse = self.parse(data: data) {
                // These values are always returned
                self.playQueue.currentIndex = jukeboxResponse.currentIndex
                self.gain = jukeboxResponse.gain
                self.isPlaying = jukeboxResponse.isPlaying
                self.position = jukeboxResponse.position
                self.positionLastReportedAt = Date()
                
                // Songs are only returned when calling the "get" action
                if let songs = jukeboxResponse.songs {
                    _ = self.playQueue.clear()
                    for song in songs {
                        song.queue()
                    }
                    
                    NotificationCenter.postOnMainThread(name: Notifications.songPlaybackStarted)
                    NotificationCenter.postOnMainThread(name: Notifications.jukeboxSongInfo)
                }
                
                let delay = action == .get ? 30 : 0.5
                self.getInfo(delay: delay)
            } else if let error = error {
                self.handleConnectionError(error: error)
            }
        }
        dataTask.resume()
    }
    
    private func handleConnectionError(error: Error) {
        DispatchQueue.main.async {
            let message = "There was an error controlling the Jukebox.\n\nError: \(error)"
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addOKAction()
            UIApplication.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
        }
    }
    
    private func parse(data: Data) -> JukeboxResponse? {
        let root = RXMLElement(fromXMLData: data)
        if root.isValid {
            if let error = root.child("error"), error.isValid {
                let code = error.attribute("code").intXML
                let message = error.attribute("message").stringXMLOptional ?? "Unknown error"
                if code == 50 {
                    // User is not authorized to control the jukebox
                    settings.isJukeboxEnabled = false
                    NotificationCenter.postOnMainThread(name: Notifications.jukeboxDisabled)
                }
                
                DispatchQueue.main.async {
                    let message = "There was an error controlling the Jukebox.\n\nError \(code): \(message)"
                    let alert = UIAlertController(title: "Subsonic Error", message: message, preferredStyle: .alert)
                    alert.addOKAction()
                    UIApplication.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
                }
            } else if let status = root.child("jukeboxStatus") {
                return JukeboxResponse(songs: nil,
                                       currentIndex: status.attribute("currentIndex").intXML,
                                       isPlaying: status.attribute("playing").boolXML,
                                       gain: status.attribute("gain").floatXML,
                                       position: status.attribute("position").intXML)
            } else if let playlist = root.child("jukeboxPlaylist") {
                var songs = [Song]()
                playlist.iterate("entry") { e, _ in
                    songs.append(Song(serverId: self.serverId, element: e))
                }
                return JukeboxResponse(songs: songs,
                                       currentIndex: playlist.attribute("currentIndex").intXML,
                                       isPlaying: playlist.attribute("playing").boolXML,
                                       gain: playlist.attribute("gain").floatXML,
                                       position: playlist.attribute("position").intXML)
            }
        } else {
            DispatchQueue.main.async {
                let message = "There was an error controlling the Jukebox.\n\nError reading the response from Subsonic."
                let alert = UIAlertController(title: "Subsonic Error", message: message, preferredStyle: .alert)
                alert.addOKAction()
                UIApplication.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
            }
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
