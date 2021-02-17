//
//  Song.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

final class Song: Codable, Hashable, CustomStringConvertible {
    private var store: Store { Resolver.resolve() }
    private var settings: Settings { Resolver.resolve() }
    private var player: BassPlayer { Resolver.resolve() }
    private var playQueue: PlayQueue { Resolver.resolve() }
            
    let serverId: Int
    let id: Int
    let title: String
    let coverArtId: String?
    let parentFolderId: Int?
    let tagArtistName: String?
    let tagAlbumName: String?
    let playCount: Int?
    let year: Int?
    let tagArtistId: Int?
    let tagAlbumId: Int?
    let genre: String?
    let path: String
    let suffix: String
    let transcodedSuffix: String?
    let duration: Int
    let kiloBitrate: Int
    let track: Int?
    let discNumber: Int?
    let size: Int
    let isVideo: Bool
    let createdDate: Date
    let starredDate: Date?
    
    var localSuffix: String? { transcodedSuffix ?? suffix }
    var localPath: String {
        let serverPathPrefix: String
        if let server = store.server(id: serverId) {
            serverPathPrefix = server.path
        } else {
            serverPathPrefix = "Unknown"
        }
        let localPath = FileSystem.downloadsDirectory.appendingPathComponent(serverPathPrefix).appendingPathComponent(path).path
        return localPath
    }
    
    var localTempPath: String {
        let serverPathPrefix: String
        if let server = store.server(id: serverId) {
            serverPathPrefix = server.path
        } else {
            serverPathPrefix = "Unknown"
        }
        let localPath = FileSystem.tempDownloadsDirectory.appendingPathComponent(serverPathPrefix).appendingPathComponent(path).path
        return localPath
    }
    var currentPath: String { isTempCached ? localTempPath : localPath }
    
    var isTempCached: Bool {
        // If the song is fully cached, then it doesn't matter if there is a temp cache file
        //if self.isFullyCached { return false }
        
        // Return YES if the song exists in the temp folder
        return FileManager.default.fileExists(atPath: localTempPath)
    }
    
    var localFileSize: Int {
        var st = stat()
        stat(currentPath, &st)
        return Int(st.st_size)
        
//        return URL(fileURLWithPath: currentPath).fileSize ?? 0
        
        
        // NOTE: This is almost certainly no longer the case
        // Using C instead of Cocoa because of a weird crash on iOS 5 devices in the audio engine
        // Asked question here: http://stackoverflow.com/questions/10289536/sigsegv-segv-accerr-crash-in-nsfileattributes-dealloc-when-autoreleasepool-is-dr
        // Still waiting for an answer on what the crash could be, so this is my temporary "solution"
//        var st = stat()
//        stat(currentPath.cString(using: .utf8), &st)
//        return Int(st.st_size)
        
//        return FileManager.default.attributesOfItem(atPath: currentPath)[.size]
    }
    
    var fileExists: Bool {
        // Filesystem check
        return FileManager.default.fileExists(atPath: currentPath)
        
        // Database check
        //return [self.db stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ?", [self.path md5]] ? YES : NO;
    }
    
    var estimatedKiloBitrate: Int {
        let currentMaxBitrate = settings.currentMaxBitrate
        
        // Default to 128 if there is no bitrate for this song object (should never happen)
        var rate = kiloBitrate == 0 ? 128 : kiloBitrate
        
        // Check if this is being transcoded to the best of our knowledge
        if transcodedSuffix != nil {
            // This is probably being transcoded, so attempt to determine the bitrate
            if (rate > 128 && currentMaxBitrate == 0) {
                rate = 128 // Subsonic default transcoding bitrate
            } else if rate > currentMaxBitrate && currentMaxBitrate != 0 {
                rate = currentMaxBitrate
            }
        } else {
            // This is not being transcoded between formats, however bitrate limiting may be active
            if rate > currentMaxBitrate && currentMaxBitrate != 0 {
                rate = currentMaxBitrate
            }
        }

        return rate
    }
    
    init(serverId: Int, id: Int, title: String, coverArtId: String?, parentFolderId: Int, tagArtistName: String?, tagAlbumName: String?, playCount: Int, year: Int, tagArtistId: Int, tagAlbumId: Int, genre: String?, path: String, suffix: String, transcodedSuffix: String?, duration: Int, kiloBitrate: Int, track: Int, discNumber: Int, size: Int, isVideo: Bool, createdDate: Date, starredDate: Date?) {
        self.serverId = serverId
        self.id = id
        self.title = title
        self.coverArtId = coverArtId
        self.parentFolderId = parentFolderId
        self.tagArtistName = tagArtistName
        self.tagAlbumName = tagAlbumName
        self.playCount = playCount
        self.year = year
        self.tagArtistId = tagArtistId
        self.tagAlbumId = tagAlbumId
        self.genre = genre
        self.path = path
        self.suffix = suffix
        self.transcodedSuffix = transcodedSuffix
        self.duration = duration
        self.kiloBitrate = kiloBitrate
        self.track = track
        self.discNumber = discNumber
        self.size = size
        self.isVideo = isVideo
        self.createdDate = createdDate
        self.starredDate = starredDate
    }
    
    init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.id = element.attribute("id").intXML
        self.title = element.attribute("title").stringXML
        self.coverArtId = element.attribute("coverArt").stringXMLOptional
        self.parentFolderId = element.attribute("parent").intXML
        self.tagArtistName = element.attribute("artist").stringXMLOptional
        self.tagAlbumName = element.attribute("album").stringXMLOptional
        self.playCount = element.attribute("playCount").intXML
        self.year = element.attribute("year").intXMLOptional
        self.tagArtistId = element.attribute("artistId").intXMLOptional
        self.tagAlbumId = element.attribute("albumId").intXMLOptional
        self.genre = element.attribute("genre").stringXMLOptional
        self.path = element.attribute("path").stringXML
        self.suffix = element.attribute("suffix").stringXML
        self.transcodedSuffix = element.attribute("transcodedSuffix").stringXMLOptional
        self.duration = element.attribute("duration").intXML
        self.kiloBitrate = element.attribute("bitRate").intXML
        self.track = element.attribute("track").intXMLOptional
        self.discNumber = element.attribute("discNumber").intXMLOptional
        self.size = element.attribute("size").intXML
        self.isVideo = element.attribute("isVideo").boolXML
        self.createdDate = element.attribute("created").dateXML
        self.starredDate = element.attribute("starred").dateXMLOptional
    }
    
    // MARK: Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(serverId)
        hasher.combine(id)
    }
    
    static func ==(lhs: Song, rhs: Song) -> Bool {
        return lhs.serverId == rhs.serverId && lhs.id == rhs.id
    }
    
    // MARK: ISMSSong+DAO
    
    var isFullyCached: Bool {
        return store.isDownloadFinished(song: self)
    }

    var downloadProgress: Float {
        var downloadProgress: Float = 0
        
        if isFullyCached {
            downloadProgress = 1
        } else {
            var bitrate = estimatedKiloBitrate
            if player.isPlaying, let currentStream = player.currentStream {
                bitrate = Bass.estimateKiloBitrate(bassStream: currentStream)
            }
            
            if transcodedSuffix != nil {
                // This is a transcode, so we'll want to use the actual bitrate if possible
                if let currentSong = playQueue.currentSong, currentSong == self {
                    // This is the current playing song, so see if BASS has an actual bitrate for it
                    if player.kiloBitrate > 0 {
                        // Bass has a non-zero bitrate, so use that for the calculation
                        bitrate = player.kiloBitrate
                    }
                }
            }
            let totalSize = bytesForSeconds(seconds: Double(duration), kiloBitrate: bitrate)
            downloadProgress = Float(localFileSize) / Float(totalSize)
        }
        
        // Keep within bounds
        downloadProgress = downloadProgress < 0 ? 0 : downloadProgress
        downloadProgress = downloadProgress > 1 ? 1 : downloadProgress
        
        // The song hasn't started downloading yet
        return downloadProgress;
    }
}

extension Song: TableCellModel {
    var primaryLabelText: String? { title }
    var secondaryLabelText: String? { tagArtistName }
    var durationLabelText: String? { formatTime(seconds: duration) }
    var isDownloaded: Bool { isFullyCached }
    var isDownloadable: Bool { !isVideo && !isFullyCached }
    
    func download() { _ = store.addToDownloadQueue(song: self) }
    func queue() { _ = store.queue(song: self) }
    func queueNext() { _ = store.queueNext(song: self) }
}

extension UniversalTableViewCell {
    func update(song: Song, number: Bool = true, cached: Bool = true, art: Bool = false, secondary: Bool = true, duration: Bool = true) {
        var showNumber = false
        if number, let track = song.track {
            showNumber = true
            self.number = track
        }
        show(cached: cached, number: showNumber, art: art, secondary: secondary, duration: duration)
        update(model: song)
    }
}
