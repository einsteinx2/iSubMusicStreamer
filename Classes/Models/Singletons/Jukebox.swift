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
    @LazyInjected private var playQueue: PlayQueue
    @LazyInjected private var settings: Settings
    
    private(set) var isPlaying = false
    private(set) var currentIndex = -1
    private(set) var gain: Float = 0.0
    private(set) var position = 0
    private(set) var positionLastReportedAt = Date()
    
    private let sessionDelegate = SelfSignedCertURLSessionDelegate()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpMaximumConnectionsPerHost = 1
        return URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)
    }()
    
    func playSong(index: Int) {
        queueDataTask(action: "skip", parameters: ["index": index])
        playQueue.currentIndex = index
    }
    
    func play() {
        queueDataTask(action: "start")
        isPlaying = true
    }
    
    func stop() {
        queueDataTask(action: "stop")
        isPlaying = false
    }
    
    func skipPrev() {
        let index = playQueue.currentIndex - 1
        if index >= 0 {
            playSong(index: index)
            isPlaying = true
        }
    }
    
    func skipNext() {
        // TODO: implement this
//        NSInteger index = PlayQueue.shared.currentIndex + 1;
//        if (index <= ([databaseS.currentPlaylistDbQueue intForQuery:@"SELECT COUNT(*) FROM jukeboxCurrentPlaylist"] - 1)) {
//            [self playSongAtPosition:@(index)];
//            self.isPlaying = YES;
//        } else {
//            [NSNotificationCenter postNotificationToMainThreadWithName:Notifications.songPlaybackEnded];
//            [self stop];
//            self.isPlaying = NO;
//        }
    }
    
    func setVolume(level: Float) {
        queueDataTask(action: "setGain", parameters: ["gain": level])
    }
    
    func seek(seconds: Int) {
        // TODO: implement this
        // Subsonic supports this using the "skip" action with the "offset" parameter and reports back the seek position with the "position" attribute of "jukeboxStatus"
    }
    
    func add(songId: Int) {
        queueDataTask(action: "add", parameters: ["id": songId])
    }
    
    func add(songIds: [Int]) {
        if songIds.count > 0 {
            queueDataTask(action: "add", parameters: ["id": songIds])
        }
    }
    
    func remove(songId: Int) {
        queueDataTask(action: "remove", parameters: ["id": songId])
    }
    
    func replacePlaylistWithLocal() {
        // TODO: implement this
//        [self clearRemotePlaylist];
//
//        __block NSMutableArray *songIds = [[NSMutableArray alloc] init];
//        [databaseS.currentPlaylistDbQueue inDatabase:^(FMDatabase *db) {
//            NSString *table = PlayQueue.shared.isShuffle ? @"jukeboxShufflePlaylist" : @"jukeboxCurrentPlaylist";
//            FMResultSet *result = [db executeQuery:[NSString stringWithFormat:@"SELECT songId FROM %@", table]];
//            while ([result next]) {
//                @autoreleasepool {
//                    NSString *songId = [result stringForColumnIndex:0];
//                    if (songId) [songIds addObject:songId];
//                }
//            }
//            [result close];
//        }];
//
//        [self addSongs:songIds];
    }
    
    // TODO: Why are their 2 clear methods?
    func clearPlaylist() {
        queueDataTask(action: "clear")
        // TODO: implement this
//        [databaseS resetJukeboxPlaylist];
    }
    
    func clearRemotePlaylist() {
        queueDataTask(action: "clear")
    }
    
    func shuffle() {
        queueDataTask(action: "shuffle")
        // TODO: implement this
//        [databaseS resetJukeboxPlaylist];
    }
    
    private var getInfoWorkItem: DispatchWorkItem?
    func getInfo() {
        // Make sure this doesn't run a bunch of times in a row
        getInfoWorkItem?.cancel()
        let getInfoWorkItem = DispatchWorkItem {
            // TODO: implement this
            // Call the standard queueDataTask with action "get" and no parameters
    //        if (settingsS.isJukeboxEnabled) {
    //            [self queueGetInfoDataTask];
    //            if (PlayQueue.shared.isShuffle) {
    //                [databaseS resetShufflePlaylist];
    //            } else {
    //                [databaseS resetJukeboxPlaylist];
    //            }
    //
    //            // Keep reloading every 30 seconds if there is no activity so that the player stays updated if visible
    //            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(jukeboxGetInfoInternal) object:nil];
    //            [self performSelector:@selector(jukeboxGetInfoInternal) withObject:nil afterDelay:30.0];
    //        }
        }
        self.getInfoWorkItem = getInfoWorkItem
        DispatchQueue.main.async(after: 0.5, execute: getInfoWorkItem)
    }
    
    private func queueDataTask(action: String, parameters: [String: Any]? = nil) {
        var finalParameters = parameters ?? [:]
        finalParameters["action"] = action
        
        // TODO: implement this
        // TODO: Don't hard code server id
        guard let request = URLRequest(serverId: settings.currentServerId, subsonicAction: "jukeboxControl", parameters: finalParameters) else {
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
                    // TODO: Implement this
                    if self.playQueue.isShuffle {
                        //[databaseS resetShufflePlaylist];
                    } else {
                        //[databaseS resetJukeboxPlaylist];
                    }
                    
                    for song in songs {
                        if song.path.count > 0 {
                            // TODO: implement this
                            if self.playQueue.isShuffle {
                                //[aSong insertIntoTable:@"jukeboxShufflePlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
                            } else {
                                // [aSong insertIntoTable:@"jukeboxCurrentPlaylist" inDatabaseQueue:databaseS.currentPlaylistDbQueue];
                            }
                        }
                    }
                    
                    NotificationCenter.postOnMainThread(name: Notifications.songPlaybackStarted)
                    NotificationCenter.postOnMainThread(name: Notifications.jukeboxSongInfo)
                }
                
                self.getInfo()
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
                    // TODO: implement this
                    // TODO: Support multiple server IDs
                    songs.append(Song(serverId: self.settings.currentServerId, element: e))
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
