//
//  Song.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

// TODO: implement this - Remove NSSecureCoding and use only Codable protocol
@objc(ISMSSong) final class Song: NSObject, NSCopying, Codable {
    private var store: Store { Resolver.resolve() }
    private var settings: Settings { Resolver.resolve() }
    private var player: BassGaplessPlayer { Resolver.resolve() }
    private var playQueue: PlayQueue { Resolver.resolve() }
    
//    static let supportsSecureCoding: Bool = true
        
    @objc let serverId: Int
    @objc(songId) let id: Int
    @objc let title: String
    @objc let coverArtId: String?
    @objc let parentFolderId: Int
    @objc let tagArtistName: String?
    @objc let tagAlbumName: String?
    @objc let playCount: Int
    @objc let year: Int
    @objc let tagArtistId: Int
    @objc let tagAlbumId: Int
    @objc let genre: String?
    @objc let path: String
    @objc let suffix: String
    @objc let transcodedSuffix: String?
    @objc let duration: Int
    @objc let kiloBitrate: Int
    @objc let track: Int
    @objc let discNumber: Int
    @objc let size: Int
    @objc let isVideo: Bool
    
    @objc var localSuffix: String? { transcodedSuffix ?? suffix }
    @objc var localPath: String {
        let serverPathPrefix: String
        if let server = store.server(id: serverId) {
            serverPathPrefix = server.path
        } else {
            serverPathPrefix = "Unknown"
        }
        let localPath = FileSystem.downloadsDirectory.appendingPathComponent(serverPathPrefix).appendingPathComponent(path).path
        return localPath
    }
    
    @objc var localTempPath: String {
        let serverPathPrefix: String
        if let server = store.server(id: serverId) {
            serverPathPrefix = server.path
        } else {
            serverPathPrefix = "Unknown"
        }
        let localPath = FileSystem.tempDownloadsDirectory.appendingPathComponent(serverPathPrefix).appendingPathComponent(path).path
        return localPath
    }
    @objc var currentPath: String { isTempCached ? localTempPath : localPath }
    
    @objc var isTempCached: Bool {
        // If the song is fully cached, then it doesn't matter if there is a temp cache file
        //if self.isFullyCached { return false }
        
        // Return YES if the song exists in the temp folder
        return FileManager.default.fileExists(atPath: localTempPath)
    }
    
    @objc var localFileSize: Int {
        return URL(fileURLWithPath: currentPath).fileSize ?? 0
        
        
        // NOTE: This is almost certainly no longer the case
        // Using C instead of Cocoa because of a weird crash on iOS 5 devices in the audio engine
        // Asked question here: http://stackoverflow.com/questions/10289536/sigsegv-segv-accerr-crash-in-nsfileattributes-dealloc-when-autoreleasepool-is-dr
        // Still waiting for an answer on what the crash could be, so this is my temporary "solution"
//        var st = stat()
//        stat(currentPath.cString(using: .utf8), &st)
//        return Int(st.st_size)
        
//        return FileManager.default.attributesOfItem(atPath: currentPath)[.size]
    }
    
    @objc var fileExists: Bool {
        // Filesystem check
        return FileManager.default.fileExists(atPath: currentPath)
        
        // Database check
        //return [self.db stringForQuery:@"SELECT md5 FROM cachedSongs WHERE md5 = ?", [self.path md5]] ? YES : NO;
    }
    
    @objc var estimatedKiloBitrate: Int {
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
    
    @objc init(serverId: Int, id: Int, title: String, coverArtId: String?, parentFolderId: Int, tagArtistName: String?, tagAlbumName: String?, playCount: Int, year: Int, tagArtistId: Int, tagAlbumId: Int, genre: String?, path: String, suffix: String, transcodedSuffix: String?, duration: Int, kiloBitrate: Int, track: Int, discNumber: Int, size: Int, isVideo: Bool) {
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
        super.init()
    }
    
    @objc init(serverId: Int, element: RXMLElement) {
        self.serverId = serverId
        self.id = element.attribute("id").intXML
        self.title = element.attribute("title").stringXML
        self.coverArtId = element.attribute("coverArt").stringXMLOptional
        self.parentFolderId = element.attribute("parent").intXML
        self.tagArtistName = element.attribute("artist").stringXMLOptional
        self.tagAlbumName = element.attribute("album").stringXMLOptional
        self.playCount = element.attribute("playCount").intXML
        self.year = element.attribute("year").intXML
        self.tagArtistId = element.attribute("artistId").intXML
        self.tagAlbumId = element.attribute("albumId").intXML
        self.genre = element.attribute("genre").stringXMLOptional
        self.path = element.attribute("path").stringXML
        self.suffix = element.attribute("suffix").stringXML
        self.transcodedSuffix = element.attribute("transcodedSuffix").stringXMLOptional
        self.duration = element.attribute("duration").intXML
        self.kiloBitrate = element.attribute("bitRate").intXML
        self.track = element.attribute("track").intXML
        self.discNumber = element.attribute("discNumber").intXML
        self.size = element.attribute("size").intXML
        self.isVideo = element.attribute("isVideo").boolXML
        super.init()
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        Song(serverId: serverId, id: id, title: title, coverArtId: coverArtId, parentFolderId: parentFolderId, tagArtistName: tagArtistName, tagAlbumName: tagAlbumName, playCount: playCount, year: year, tagArtistId: tagArtistId, tagAlbumId: tagAlbumId, genre: genre, path: path, suffix: suffix, transcodedSuffix: transcodedSuffix, duration: duration, kiloBitrate: kiloBitrate, track: track, discNumber: discNumber, size: size, isVideo: isVideo)
    }
    
    override var description: String {
        "\(super.description): serverId: \(serverId), id: \(id), title: \(title)"
    }
    
    override var hash: Int {
        id.hashValue
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? Song {
            return self === object || (serverId == object.serverId && id == object.id)
        }
        return false
    }
    
    // MARK: ISMSSong+DAO
    
    @objc var isFullyCached: Bool {
        return store.isDownloadFinished(song: self)
    }

    @objc var downloadProgress: Float {
        var downloadProgress: Float = 0
        
        if isFullyCached {
            downloadProgress = 1
        } else {
            var bitrate = estimatedKiloBitrate
            if player.isPlaying {
                bitrate = BassWrapper.estimateKiloBitrate(player.currentStream)
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
    
    @objc func removeFromDownloads() -> Bool {
        return store.deleteDownloadedSong(serverId: serverId, songId: id)
        
        // TODO: Delete file here? This used to be a database only method
    }
}

extension Song: TableCellModel {
    var primaryLabelText: String? { title }
    var secondaryLabelText: String? { tagArtistName }
    var durationLabelText: String? { NSString.formatTime(Double(duration)) }
    var isCached: Bool { isFullyCached }
    func download() {
        _ = store.addToDownloadQueue(song: self)
    }
    func queue() {
        _ = store.queue(song: self)
    }
}
